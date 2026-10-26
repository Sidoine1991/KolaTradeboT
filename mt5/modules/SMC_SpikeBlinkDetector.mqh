//+------------------------------------------------------------------+
//| SMC_SpikeBlinkDetector.mqh                                        |
//| Flèche clignotante sur la DERNIÈRE bougie M1 du spike.            |
//| GOOD/PERFECT + M1/M5/M15 + pattern frais au canal → blink confirmé |
//+------------------------------------------------------------------+
#property copyright "TradBOT SMC"
#property strict

#ifndef SMC_SPIKE_BLINK_DETECTOR_MQH
#define SMC_SPIKE_BLINK_DETECTOR_MQH

#ifndef SPIKE_BLINK_INPUTS_DEFINED
#define SPIKE_BLINK_INPUTS_DEFINED
input group "=== SPIKE BLINK DETECTOR (GOOD/PERFECT) ==="
input bool   UseSpikeBlinkDetector     = true;
input int    SpikeBlinkMinAlignedTF    = 3;      // FIX v1.34: exiger M1+M5+M15 (était 2)
input double SpikeBlinkApproachATR     = 0.35;
input int    SpikeBlinkIntervalMs      = 450;
input bool   SpikeBlinkAutoFire        = true;
input double SpikeBlinkSL_ATR          = 1.2;
input double SpikeBlinkTP_ATR          = 2.4;
input double SpikeBlinkMaxSLUSD        = 2.0;    // FIX v1.34: SL hard-cap $2 pour capturer le spike
input double SpikeBlinkMinTPUSD        = 0.80;   // FIX v1.34: TP mini $ pour sortir en gain
input bool   SpikeBlinkRequireTripleTF = true;   // Compatibilité set-file; M1/M5/M15 toujours obligatoires
input int    SpikeBlinkSetupMaxAgeMinutes = 15;  // Expiration du setup armé; ne garantit pas la durée d'une chaîne
input bool   UseSpikeBlinkHTFWaitOverride = false; // v1.57 OFF: WAIT ne doit plus ouvrir via HTF
#endif

#ifndef G_SMC_GOM_EXTERN
extern bool     g_smcGomConnected;
extern int      g_smcGomVerdictNum;
extern int      g_smcGomVerdictNumServer;
extern string   g_smcTfM1Dir;
extern string   g_smcTfM1DirLive;
extern string   g_smcTfM5Dir;
extern string   g_smcTfM15Dir;
extern string   g_smcTfH4Dir;
extern string   g_smcTfD1Dir;
#endif
extern int      g_spikeChainDirection;
extern int      g_spikeChainStrongBars;

// Forward declaration for function defined in SMC_Universal.mq5
bool SMC_BCNativeBypass(const string symbol, const int dirSign);

enum ENUM_SPIKE_BLINK_STATE
{
   SPIKE_BLINK_IDLE = 0,
   SPIKE_BLINK_ARMED,
   SPIKE_BLINK_ARMED_STRONG,
   SPIKE_BLINK_FIRED
};

struct SpikeBlinkState
{
   ENUM_SPIKE_BLINK_STATE state;
   int      dirSign;
   double   targetPrice;
   datetime barTime;
   string   targetSource;
   datetime armedSince;
   bool     blinkVisible;
   int      blinkTransitions;
   bool     htfWaitOverride;
   string   arrowName;
   string   labelName;
};

SpikeBlinkState g_spikeBlink;

void SMC_SpikeBlink_LogBlocked(const string reason)
{
   static datetime lastLogTime = 0;
   static string lastReason = "";
   datetime now = TimeCurrent();
   if(reason == lastReason && now - lastLogTime < 10)
      return;
   lastReason = reason;
   lastLogTime = now;
   Print("[SPIKE-BLINK] WAIT ", _Symbol, " | ", reason,
         " | GOM=", g_smcGomVerdictNum, "/", g_smcGomVerdictNumServer,
         " connected=", g_smcGomConnected,
         " entryAllowed=", g_smcGomEntryAllowed,
         " M1=", (StringLen(g_smcTfM1DirLive) > 0 ? g_smcTfM1DirLive : g_smcTfM1Dir),
         " M5=", g_smcTfM5Dir, " M15=", g_smcTfM15Dir,
         " priceFresh=", g_smcMarketPriceFresh,
         " forecast5m=", g_smcForecast5mReady,
         " forecastVn=", g_smcGomVerdictForecastNum,
         " htfSimple=", g_smcSpikeHTFSimpleAllowed,
         " H4=", g_smcTfH4Dir, " D1=", g_smcTfD1Dir,
         " chain=", (int)g_spikeChainState, "/", g_spikeChainDirection,
         "/", g_spikeChainStrongBars);
}

int SMC_SpikeBlink_TfDirSign(const string d)
{
   string u = d;
   StringToUpper(u);
   if(StringFind(u, "BULL") >= 0 || u == "BUY" || u == "UP" || u == "LONG") return 1;
   if(StringFind(u, "BEAR") >= 0 || u == "SELL" || u == "DOWN" || u == "SHORT") return -1;
   return 0;
}

int SMC_SpikeBlink_EffectiveVn()
{
   // Préférer le verdict trading; si overlay a forcé WAIT mais serveur GOOD/PERFECT,
   // utiliser le serveur (évite bandeau jaune qui tue le fire).
   int vn = g_smcGomVerdictNum;
   if(MathAbs(vn) >= 2) return vn;
   if(MathAbs(g_smcGomVerdictNumServer) >= 2)
      return g_smcGomVerdictNumServer;
   return vn;
}

bool SMC_SpikeBlink_TripleTFAligned(const int dirSign)
{
   if(dirSign == 0) return false;
   string m1 = (StringLen(g_smcTfM1DirLive) > 0) ? g_smcTfM1DirLive : g_smcTfM1Dir;
   return (SMC_SpikeBlink_TfDirSign(m1) == dirSign &&
           SMC_SpikeBlink_TfDirSign(g_smcTfM5Dir) == dirSign &&
           SMC_SpikeBlink_TfDirSign(g_smcTfM15Dir) == dirSign);
}

int SMC_SpikeBlink_NativeDir(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   if(StringFind(s, "GAINX") >= 0 || StringFind(s, "BOOM") >= 0) return 1;
   if(StringFind(s, "PAINX") >= 0 || StringFind(s, "CRASH") >= 0) return -1;
   if(IsBoomLikeSymbol(symbol)) return 1;
   if(IsCrashLikeSymbol(symbol)) return -1;
   return 0;
}

bool SMC_SpikeBlink_D1H4Aligned(const int dirSign)
{
   return (dirSign != 0 &&
           SMC_SpikeBlink_TfDirSign(g_smcTfD1Dir) == dirSign &&
           SMC_SpikeBlink_TfDirSign(g_smcTfH4Dir) == dirSign);
}

bool SMC_SpikeBlink_HasFreshTick(const string symbol)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick) || tick.time <= 0 ||
      tick.bid <= 0.0 || tick.ask <= 0.0)
      return false;
   int age = (int)(TimeCurrent() - tick.time);
   return (age >= 0 && age <= MathMax(1, GOMMaxLiveQuoteAgeSec));
}

bool SMC_SpikeBlink_HTFWaitSetup(const string symbol, const int dirSign,
                                 const bool liveSpike, string &reason)
{
   reason = "";
   if(!UseSpikeBlinkHTFWaitOverride || symbol != _Symbol ||
      dirSign == 0 || dirSign != SMC_SpikeBlink_NativeDir(symbol))
   {
      reason = "exception HTF désactivée ou direction non native";
      return false;
   }
   bool serverQualifiedDirection = (g_smcSpikeHTFSimpleAllowed &&
                                   (g_smcGomVerdictNum == 0 ||
                                    ((g_smcGomVerdictNum > 0) ? 1 : -1) == dirSign));
   if(!g_smcGomConnected ||
      (g_smcGomVerdictNum != 0 && !serverQualifiedDirection))
   {
      reason = "exception réservée au GOM WAIT ou SIMPLE HTF autorisé par serveur";
      return false;
   }
   if(g_smcLastGOMPoll <= 0 || TimeCurrent() < g_smcLastGOMPoll ||
      TimeCurrent() - g_smcLastGOMPoll > 120)
   {
      reason = "état GOM/MTF trop ancien";
      return false;
   }
   if(MathAbs(g_smcGomVerdictNumServer) >= 1 &&
      ((g_smcGomVerdictNumServer > 0) ? 1 : -1) != dirSign)
   {
      reason = "verdict serveur non-WAIT opposé au spike";
      return false;
   }
   if(!SMC_SpikeBlink_D1H4Aligned(dirSign))
   {
      reason = "D1 et H4 ne confirment pas le sens natif du spike";
      return false;
   }

   bool chainActive = (g_spikeChainState == SPIKE_STATE_CHAIN_ACTIVE &&
                       g_spikeChainDirection == dirSign &&
                       g_spikeChainStrongBars >= 2);
   if(!liveSpike && !chainActive)
   {
      reason = "aucun spike M1 live ni chaîne native confirmée";
      return false;
   }
   if(!SMC_SpikeBlink_HasFreshTick(symbol))
   {
      reason = "cotation bid/ask locale périmée";
      return false;
   }
   if(g_smcForecast5mReady && g_smcForecastHorizonMinutes == 5 &&
      g_smcGomVerdictForecastNum != 0 &&
      ((g_smcGomVerdictForecastNum > 0) ? 1 : -1) != dirSign)
   {
      if(!g_smcSpikeHTFSimpleAllowed ||
         MathAbs(g_smcGomVerdictForecastNum) != 1)
      {
         reason = "prévision 5 min forte ou non autorisée opposée au spike";
         return false;
      }
   }
   return true;
}

double SMC_SpikeBlink_ATR()
{
   double atr = 0.0;
   if(g_spikeBlinkAtrHandle == INVALID_HANDLE)
      g_spikeBlinkAtrHandle = iATR(_Symbol, PERIOD_M1, 14);
   if(g_spikeBlinkAtrHandle != INVALID_HANDLE)
   {
      double buf[];
      if(CopyBuffer(g_spikeBlinkAtrHandle, 0, 0, 1, buf) > 0)
         atr = buf[0];
   }
   if(atr <= 0)
      atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;
   return atr;
}

bool SMC_SpikeBlink_CapSLTP(const int dirSign, const double entry, const double lot,
                            double &sl, double &tp)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(tickSize <= 0) tickSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickVal <= 0 || lot <= 0 || entry <= 0) return false;

   double maxSL = MathMax(0.50, SpikeBlinkMaxSLUSD);
   double maxDist = (maxSL / (tickVal * lot)) * tickSize;
   double atr = SMC_SpikeBlink_ATR();
   double atrDist = atr * SpikeBlinkSL_ATR;
   double slDist = MathMin(atrDist, maxDist);

   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int stopsLvl = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (double)(stopsLvl + 2) * pt;
   if(slDist < minDist) slDist = minDist;

   if(dirSign > 0)
      sl = NormalizeDouble(entry - slDist, dg);
   else
      sl = NormalizeDouble(entry + slDist, dg);

   // TP : viser au moins SpikeBlinkMinTPUSD, sinon ATR TP
   double minTP = MathMax(0.20, SpikeBlinkMinTPUSD);
   double tpDistATR = atr * SpikeBlinkTP_ATR;
   double tpDistUSD = (minTP / (tickVal * lot)) * tickSize;
   double tpDist = MathMax(tpDistATR, tpDistUSD);
   // RR minimum 1.5x le SL pour sortir en gain
   if(tpDist < slDist * 1.5) tpDist = slDist * 1.5;

   if(dirSign > 0)
      tp = NormalizeDouble(entry + tpDist, dg);
   else
      tp = NormalizeDouble(entry - tpDist, dg);
   return true;
}

bool SMC_SpikeBlink_LiveCandle(const int dirSign, datetime &tOut, double &pxOut)
{
   tOut = 0;
   pxOut = 0.0;
   if(dirSign == 0) return false;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 3, r) < 2)
      return false;
   double atr = SMC_SpikeBlink_ATR();
   int idx = 0;
   double body0 = MathAbs(r[0].close - r[0].open);
   double rng0  = r[0].high - r[0].low;
   bool spike0 = (body0 >= atr * 0.70 || rng0 >= atr * 1.05);
   bool dir0 = (dirSign > 0 && r[0].close > r[0].open) ||
               (dirSign < 0 && r[0].close < r[0].open);
   if(!spike0 || !dir0)
   {
      idx = 1;
      double body1 = MathAbs(r[1].close - r[1].open);
      double rng1  = r[1].high - r[1].low;
      bool spike1 = (body1 >= atr * 0.70 || rng1 >= atr * 1.05);
      bool dir1 = (dirSign > 0 && r[1].close > r[1].open) ||
                  (dirSign < 0 && r[1].close < r[1].open);
      if(!spike1 || !dir1)
         return false;
   }
   tOut = r[idx].time;
   pxOut = (dirSign > 0) ? r[idx].low : r[idx].high;
   return (tOut > 0 && pxOut > 0);
}

bool SMC_SpikeBlink_FindNearestLevel(const int dirSign, double &levelOut, string &srcOut)
{
   levelOut = 0.0;
   srcOut   = "";
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double px  = (dirSign > 0) ? ask : bid;
   if(px <= 0) return false;

   if(UseDowTrendline && g_dowState.active)
   {
      double dowPx = (g_dowState.projectedPrice > 0.0) ? g_dowState.projectedPrice
                   : ((g_dowState.currentEpPrice > 0.0) ? g_dowState.currentEpPrice : 0.0);
      bool dowOk = (dirSign > 0 && !g_dowState.isBearish) || (dirSign < 0 && g_dowState.isBearish);
      if(dowOk && dowPx > 0.0)
      {
         levelOut = dowPx;
         srcOut = "DOW";
         return true;
      }
   }
   return false;
}

bool SMC_SpikeBlink_IsCandlePattern(const int id, const int dirSign)
{
   if(dirSign > 0)
      return (id == PAT_BULL_ENGULFING || id == PAT_MORNING_STAR ||
              id == PAT_THREE_SOLDIERS || id == PAT_TWEEZER_BOTTOM ||
              id == PAT_HAMMER || id == PAT_BULL_HARAMI ||
              id == PAT_PIERCING_LINE);
   if(dirSign < 0)
      return (id == PAT_BEAR_ENGULFING || id == PAT_EVENING_STAR ||
              id == PAT_THREE_CROWS || id == PAT_TWEEZER_TOP ||
              id == PAT_SHOOTING_STAR || id == PAT_BEAR_HARAMI ||
              id == PAT_DARK_CLOUD_COVER);
   return false;
}

bool SMC_SpikeBlink_ChannelPatternContext(const int dirSign, double &channelLevel,
                                          string &patternName, string &reason)
{
   channelLevel = 0.0;
   patternName = "";
   reason = "";
   if(dirSign == 0)
   {
      reason = "direction de contexte invalide";
      return false;
   }

   string channelName = (dirSign > 0) ? "SMC_Chan_Lower" : "SMC_Chan_Upper";
   if(ObjectFind(0, channelName) < 0)
   {
      reason = "canal SMC absent";
      return false;
   }

   datetime now = TimeCurrent();
   double upper = SMC_TrendLineValueAt("SMC_Chan_Upper", now);
   double lower = SMC_TrendLineValueAt("SMC_Chan_Lower", now);
   double boundary = (dirSign > 0) ? lower : upper;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double px = (dirSign > 0) ? ask : bid;
   double atr = SMC_SpikeBlink_ATR();
   if(lower <= 0.0 || upper <= lower ||
      px <= 0.0 || atr <= 0.0)
   {
      reason = "prix ou limites du canal invalides";
      return false;
   }

   double maxDistance = atr * MathMax(0.85, SpikeBlinkApproachATR * 1.8);
   if(MathAbs(px - boundary) > maxDistance)
   {
      reason = "prix trop éloigné de la limite directionnelle du canal";
      return false;
   }

   SMCPS_EnsureScanned(_Symbol);
   double patternWeight = SMCPS_DirWeight(dirSign);
   if(patternWeight < PatternMinWeightedScore ||
      (SMCPS_DirStrong(dirSign) <= 0 &&
       patternWeight < PatternMinWeightedScore + 1.0))
   {
      reason = "qualité globale des patterns insuffisante";
      return false;
   }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double touchTolerance = MathMax(point * 5.0, atr * 0.25);
   int maxSetupAge = MathMax(1, SpikeBlinkSetupMaxAgeMinutes) * 60;
   for(int i = 0; i < g_smcps.hitCount; i++)
   {
      if(g_smcps.hits[i].dirSign != dirSign ||
         !SMC_SpikeBlink_IsCandlePattern(g_smcps.hits[i].id, dirSign))
         continue;
      if(g_smcps.hits[i].tf != PERIOD_M1 && g_smcps.hits[i].tf != PERIOD_M5)
         continue;
      int tfSec = PeriodSeconds(g_smcps.hits[i].tf);
      int maxPatternAge = MathMin(maxSetupAge, MathMax(60, tfSec * 2));
      if(g_smcps.hits[i].weight < 2 || g_smcps.hits[i].barTime <= 0 ||
         now < g_smcps.hits[i].barTime ||
         now - g_smcps.hits[i].barTime > maxPatternAge)
         continue;

      int shift = iBarShift(_Symbol, g_smcps.hits[i].tf,
                            g_smcps.hits[i].barTime, false);
      if(shift < 1)
         continue;
      double barLow = iLow(_Symbol, g_smcps.hits[i].tf, shift);
      double barHigh = iHigh(_Symbol, g_smcps.hits[i].tf, shift);
      double patternBoundary = SMC_TrendLineValueAt(channelName, g_smcps.hits[i].barTime);
      if(barLow <= 0.0 || barHigh < barLow || patternBoundary <= 0.0)
         continue;

      bool touched = (barLow <= patternBoundary + touchTolerance &&
                      barHigh >= patternBoundary - touchTolerance);
      if(!touched)
         continue;

      channelLevel = boundary;
      patternName = g_smcps.hits[i].name + "@" +
                    SMCPS_TfShort(g_smcps.hits[i].tf);
      return true;
   }

   reason = (dirSign > 0)
            ? "aucun pattern haussier M1/M5 frais sur SMC_Chan_Lower"
            : "aucun pattern baissier M1/M5 frais sur SMC_Chan_Upper";
   return false;
}

bool SMC_SpikeBlink_EntryReady(const string symbol, const int dirSign, string &reason)
{
   reason = "";
   if(!UseSpikeBlinkDetector || symbol != _Symbol || SMC_SpikeBlink_NativeDir(symbol) == 0)
      return true;
   if(g_spikeBlink.state != SPIKE_BLINK_ARMED &&
      g_spikeBlink.state != SPIKE_BLINK_ARMED_STRONG)
   {
      reason = "flèche Spike Blink non armée";
      return false;
   }
   if(g_spikeBlink.dirSign != dirSign || g_spikeBlink.armedSince <= 0 ||
      TimeCurrent() < g_spikeBlink.armedSince ||
      TimeCurrent() - g_spikeBlink.armedSince > MathMax(1, SpikeBlinkSetupMaxAgeMinutes) * 60)
   {
      reason = "direction ou âge du setup Spike Blink invalide";
      return false;
   }
   if(g_spikeBlink.blinkTransitions < 4 || !g_spikeBlink.blinkVisible ||
      StringLen(g_spikeBlink.arrowName) == 0 ||
      ObjectFind(0, g_spikeBlink.arrowName) < 0)
   {
      reason = "attente de la confirmation visuelle du clignotement";
      return false;
   }

   if(g_spikeBlink.htfWaitOverride)
   {
      bool liveSpike = false;
      datetime spikeBar = 0;
      double spikePrice = 0.0;
      liveSpike = SMC_SpikeBlink_LiveCandle(dirSign, spikeBar, spikePrice);
      if(!SMC_SpikeBlink_HTFWaitSetup(symbol, dirSign, liveSpike, reason))
         return false;
      return true;
   }

   int vn = SMC_SpikeBlink_EffectiveVn();
   if(!g_smcGomConnected || MathAbs(vn) < 2 ||
      ((vn > 0) ? 1 : -1) != dirSign ||
      !SMC_SpikeBlink_TripleTFAligned(dirSign))
   {
      reason = "GOM GOOD/PERFECT ou alignement M1/M5/M15 perdu";
      return false;
   }

   double channelLevel = 0.0;
   string patternName = "";
   return SMC_SpikeBlink_ChannelPatternContext(dirSign, channelLevel, patternName, reason);
}

bool SMC_SpikeBlink_HTFOverrideInFlight(const string symbol, const int dirSign)
{
   return (g_smcSpikeHTFOverrideInFlight &&
           symbol == _Symbol &&
           g_smcSpikeHTFOverrideDir == dirSign &&
           dirSign != 0);
}

int SMC_SpikeBlink_HTFDisplayDirection()
{
   return g_smcSpikeBlinkHTFDisplayDir;
}

bool SMC_SpikeBlink_OrderAllowed(const string symbol, const int dirSign,
                                const bool isMarketOrder, string &reason)
{
   reason = "";
   if(!UseSpikeBlinkDetector || symbol != _Symbol ||
      SMC_SpikeBlink_NativeDir(symbol) == 0)
      return true;
   int vnBlink = SMC_SpikeBlink_EffectiveVn();
   if(MathAbs(vnBlink) < 2 && MathAbs(g_smcGomVerdictNum) >= 2)
      vnBlink = g_smcGomVerdictNum;
   if(MathAbs(vnBlink) < 2 && MathAbs(g_smcGomVerdictNumServer) >= 2)
      vnBlink = g_smcGomVerdictNumServer;
   bool vnAligned = (MathAbs(vnBlink) >= 2 && ((vnBlink > 0) ? 1 : -1) == dirSign);
   // Scalp KOLA/OB : LIMIT autorisé si GOM GOOD/PERFECT aligné (SMVE)
   if(!isMarketOrder)
   {
      if(vnAligned)
         return true;
      reason = "ordre différé interdit; attendre flèche OU GOM GOOD/PERFECT";
      return false;
   }
   if(vnAligned)
      return true;
   return SMC_SpikeBlink_EntryReady(symbol, dirSign, reason);
}

void SMC_SpikeBlink_ClearObjects()
{
   if(StringLen(g_spikeBlink.arrowName) > 0)
      ObjectDelete(0, g_spikeBlink.arrowName);
   if(StringLen(g_spikeBlink.labelName) > 0)
      ObjectDelete(0, g_spikeBlink.labelName);
   ObjectDelete(0, "SMC_DERIV_ARROW_" + _Symbol);
   g_spikeBlink.arrowName = "";
   g_spikeBlink.labelName = "";
}

void SMC_SpikeBlink_Reset()
{
   SMC_SpikeBlink_ClearObjects();
   g_smcSpikeBlinkHTFDisplayDir = 0;
   g_spikeBlink.state        = SPIKE_BLINK_IDLE;
   g_spikeBlink.dirSign      = 0;
   g_spikeBlink.targetPrice  = 0;
   g_spikeBlink.barTime      = 0;
   g_spikeBlink.targetSource = "";
   g_spikeBlink.armedSince   = 0;
   g_spikeBlink.blinkVisible = true;
   g_spikeBlink.blinkTransitions = 0;
   g_spikeBlink.htfWaitOverride = false;
}

void SMC_SpikeBlink_DrawOrUpdate()
{
   if(g_spikeBlink.state == SPIKE_BLINK_IDLE || g_spikeBlink.targetPrice <= 0)
      return;

   bool isBuy = (g_spikeBlink.dirSign > 0);
   string base = "SPIKE_BLINK_" + _Symbol;
   g_spikeBlink.arrowName = base + "_ARR";
   g_spikeBlink.labelName = base + "_LBL";

   datetime t = (g_spikeBlink.barTime > 0) ? g_spikeBlink.barTime : iTime(_Symbol, PERIOD_M1, 0);
   if(t <= 0) t = TimeCurrent();
   color cOn  = isBuy ? clrLime : clrRed;
   color cOff = isBuy ? C'20,80,20' : C'80,20,20';
   color c    = g_spikeBlink.blinkVisible ? cOn : cOff;

   if(ObjectFind(0, g_spikeBlink.arrowName) < 0)
   {
      ObjectCreate(0, g_spikeBlink.arrowName, OBJ_ARROW, 0, t, g_spikeBlink.targetPrice);
      ObjectSetInteger(0, g_spikeBlink.arrowName, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
      ObjectSetInteger(0, g_spikeBlink.arrowName, OBJPROP_WIDTH, 5);
      ObjectSetInteger(0, g_spikeBlink.arrowName, OBJPROP_ANCHOR, isBuy ? ANCHOR_TOP : ANCHOR_BOTTOM);
      ObjectSetInteger(0, g_spikeBlink.arrowName, OBJPROP_BACK, false);
      ObjectSetInteger(0, g_spikeBlink.arrowName, OBJPROP_SELECTABLE, false);
   }
   else
      ObjectMove(0, g_spikeBlink.arrowName, 0, t, g_spikeBlink.targetPrice);
   ObjectSetInteger(0, g_spikeBlink.arrowName, OBJPROP_COLOR, c);

   string txt = g_spikeBlink.htfWaitOverride
                ? (isBuy ? "HTF SPIKE BUY SIMPLE" : "HTF SPIKE SELL SIMPLE")
                : (isBuy ? "SPIKE BUY" : "SPIKE SELL");
   if(ObjectFind(0, g_spikeBlink.labelName) < 0)
   {
      ObjectCreate(0, g_spikeBlink.labelName, OBJ_TEXT, 0, t, g_spikeBlink.targetPrice);
      ObjectSetInteger(0, g_spikeBlink.labelName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, g_spikeBlink.labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, g_spikeBlink.labelName, OBJPROP_ANCHOR, isBuy ? ANCHOR_UPPER : ANCHOR_LOWER);
   }
   ObjectSetString(0, g_spikeBlink.labelName, OBJPROP_TEXT, g_spikeBlink.blinkVisible ? txt : " ");
   ObjectSetInteger(0, g_spikeBlink.labelName, OBJPROP_COLOR, cOn);
   ObjectMove(0, g_spikeBlink.labelName, 0, t, g_spikeBlink.targetPrice);
}

void SMC_SpikeBlink_Toggle()
{
   static uint s_lastMs = 0;
   uint ms = GetTickCount();
   if(ms - s_lastMs < (uint)MathMax(200, SpikeBlinkIntervalMs)) return;
   s_lastMs = ms;
   g_spikeBlink.blinkVisible = !g_spikeBlink.blinkVisible;
   if(g_spikeBlink.state == SPIKE_BLINK_ARMED ||
      g_spikeBlink.state == SPIKE_BLINK_ARMED_STRONG)
      g_spikeBlink.blinkTransitions++;
   SMC_SpikeBlink_DrawOrUpdate();
}

bool SMC_SpikeBlink_TryFire()
{
   if(!SpikeBlinkAutoFire)
   {
      SMC_SpikeBlink_LogBlocked("auto-fire désactivé");
      return false;
   }
   if(g_spikeBlink.state != SPIKE_BLINK_ARMED && g_spikeBlink.state != SPIKE_BLINK_ARMED_STRONG)
      return false;

   bool htfOverride = g_spikeBlink.htfWaitOverride;
   int vn = SMC_SpikeBlink_EffectiveVn();
   if(htfOverride)
   {
      bool liveSpike = false;
      datetime spikeBar = 0;
      double spikePrice = 0.0;
      liveSpike = SMC_SpikeBlink_LiveCandle(g_spikeBlink.dirSign, spikeBar, spikePrice);
      string htfReason = "";
      if(!SMC_SpikeBlink_HTFWaitSetup(_Symbol, g_spikeBlink.dirSign,
                                      liveSpike, htfReason))
      {
         SMC_SpikeBlink_LogBlocked(htfReason);
         return false;
      }
   }
   else if(!g_smcGomConnected || vn == 0)
   {
      SMC_SpikeBlink_LogBlocked("verdict GOM absent ou déconnecté");
      return false;
   }
   else if(MathAbs(vn) < 2)
   {
      SMC_SpikeBlink_LogBlocked("verdict SIMPLE/WAIT; GOOD ou PERFECT requis");
      return false;
   }

   if(!htfOverride && !SMC_SpikeBlink_TripleTFAligned(g_spikeBlink.dirSign))
   {
      SMC_SpikeBlink_LogBlocked("M1/M5/M15 non alignés avec le sens du spike");
      return false;
   }

   int vnSign = (vn > 0) ? 1 : ((vn < 0) ? -1 : 0);
   if(!htfOverride && vnSign != g_spikeBlink.dirSign)
   {
      SMC_SpikeBlink_LogBlocked("verdict GOM opposé au sens du spike");
      return false;
   }
   string contextReason = "";
   if(!SMC_SpikeBlink_EntryReady(_Symbol, g_spikeBlink.dirSign, contextReason))
   {
      SMC_SpikeBlink_LogBlocked(contextReason);
      return false;
   }

   if(IsTerminalFull() || CountPositionsOurEA() >= MaxPositionsTerminal)
   {
      SMC_SpikeBlink_LogBlocked("cap de positions EA/terminal atteint");
      return false;
   }
   if(CountPositionsForSymbol(_Symbol) > 0)
   {
      SMC_SpikeBlink_LogBlocked("position déjà ouverte sur le symbole");
      return false;
   }

   double atr = SMC_SpikeBlink_ATR();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double px  = (g_spikeBlink.dirSign > 0) ? ask : bid;
   if(atr <= 0.0 || px <= 0.0 || g_spikeBlink.targetPrice <= 0.0)
   {
      SMC_SpikeBlink_LogBlocked("prix live, ATR ou niveau cible invalide");
      return false;
   }

   // Ne pas ouvrir après une impulsion déjà éloignée du niveau de départ.
   double approachMult = MathMax(0.85, SpikeBlinkApproachATR * 1.8);
   if(htfOverride)
      approachMult = MathMax(approachMult, 2.0);
   if(MathAbs(px - g_spikeBlink.targetPrice) > atr * approachMult)
   {
      SMC_SpikeBlink_LogBlocked("impulsion déjà étendue depuis le niveau (attente pullback)");
      return false;
   }
   if(!htfOverride && g_spikeBlink.targetSource == "M1_CANDLE")
   {
      MqlRates current[];
      ArraySetAsSeries(current, true);
      if(CopyRates(_Symbol, PERIOD_M1, 0, 1, current) < 1)
      {
         SMC_SpikeBlink_LogBlocked("bougie M1 live indisponible pour le filtre anti-poursuite");
         return false;
      }
      double liveBody = MathAbs(current[0].close - current[0].open);
      double liveRange = current[0].high - current[0].low;
      if(liveBody > atr * 1.15 || liveRange > atr * 1.60)
      {
         SMC_SpikeBlink_LogBlocked("bougie spike M1 déjà trop étendue (entrée en poursuite refusée)");
         return false;
      }
   }

   // Restaurer temporairement le verdict trading si overlay WAIT a bloqué le gate
   int savedVn = g_smcGomVerdictNum;
   string savedLabel = g_smcGomVerdict;
   if(!htfOverride && g_smcGomVerdictNum == 0 && MathAbs(vn) >= 2)
   {
      g_smcGomVerdictNum = vn;
      g_smcGomVerdict = (vn > 0) ? ((MathAbs(vn) >= 3) ? "PERFECT BUY" : "GOOD BUY")
                                 : ((MathAbs(vn) >= 3) ? "PERFECT SELL" : "GOOD SELL");
      Print("⚡ SPIKE_BLINK restore verdict serveur vn=", vn, " (overlay WAIT ignoré — 3TF alignés)");
   }

   if(!TryAcquireOpenLock())
   {
      SMC_SpikeBlink_LogBlocked("verrou d'ouverture déjà détenu");
      g_smcGomVerdictNum = savedVn;
      g_smcGomVerdict = savedLabel;
      return false;
   }
   g_smcSpikeHTFOverrideInFlight = htfOverride;
   g_smcSpikeHTFOverrideDir = htfOverride ? g_spikeBlink.dirSign : 0;
   ENUM_ORDER_TYPE otype = (g_spikeBlink.dirSign > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!SMC_FinalOpenGate(_Symbol, otype))
   {
      SMC_SpikeBlink_LogBlocked("gate final EA a refusé l'entrée; voir le motif GATE FINAL");
      g_smcSpikeHTFOverrideInFlight = false;
      g_smcSpikeHTFOverrideDir = 0;
      ReleaseOpenLock();
      g_smcGomVerdictNum = savedVn;
      g_smcGomVerdict = savedLabel;
      return false;
   }

   double lot = CalculateLotSize();
   if(lot <= 0)
   {
      SMC_SpikeBlink_LogBlocked("calcul de lot nul ou invalide");
      g_smcSpikeHTFOverrideInFlight = false;
      g_smcSpikeHTFOverrideDir = 0;
      ReleaseOpenLock();
      g_smcGomVerdictNum = savedVn;
      g_smcGomVerdict = savedLabel;
      return false;
   }

   double entry = px;
   double sl = 0, tp = 0;
   if(!SMC_SpikeBlink_CapSLTP(g_spikeBlink.dirSign, entry, lot, sl, tp))
   {
      SMC_SpikeBlink_LogBlocked("SL/TP non valides selon les contraintes du symbole");
      g_smcSpikeHTFOverrideInFlight = false;
      g_smcSpikeHTFOverrideDir = 0;
      ReleaseOpenLock();
      g_smcGomVerdictNum = savedVn;
      g_smcGomVerdict = savedLabel;
      return false;
   }

   string cmt = htfOverride
                ? "SPIKE_BLINK HTF_SIMPLE D1H4"
                : "SPIKE_BLINK " + g_spikeBlink.targetSource + " 3TF";
   bool ok = false;
   if(g_spikeBlink.dirSign > 0)
      ok = SafeTradeBuy(lot, _Symbol, entry, sl, tp, cmt);
   else
      ok = SafeTradeSell(lot, _Symbol, entry, sl, tp, cmt);
   g_smcSpikeHTFOverrideInFlight = false;
   g_smcSpikeHTFOverrideDir = 0;

   if(ok)
   {
      SMC_GateRegisterOpened(_Symbol, g_spikeBlink.dirSign > 0);
      RegisterOrderPlaced();
      g_spikeBlink.state = SPIKE_BLINK_FIRED;
      g_smcSpikeBlinkHTFDisplayDir = 0;
      Print("⚡ SPIKE_BLINK FIRE ", (g_spikeBlink.dirSign > 0 ? "BUY" : "SELL"),
            " ", _Symbol, " @", entry,
            " SL=", sl, " TP=", tp,
            " maxSL$=", SpikeBlinkMaxSLUSD,
            " src=", g_spikeBlink.targetSource,
            htfOverride
               ? " GOM=WAIT→SIMPLE-HTF D1/H4=OK"
               : " vn=" + IntegerToString(vn) + " 3TF=OK");
   }
   else
   {
      // Restaurer si échec
      SMC_SpikeBlink_LogBlocked(
         "ordre rejeté par le broker (retcode=" +
         IntegerToString((int)trade.ResultRetcode()) + ")");
      g_smcGomVerdictNum = savedVn;
      g_smcGomVerdict = savedLabel;
   }
   ReleaseOpenLock();
   return ok;
}

void SMC_SpikeBlink_OnTick()
{
   bool isSpikeSym = SMC_IsSynthSpikeFamily(_Symbol) ||
                     IsBoomLikeSymbol(_Symbol) ||
                     IsCrashLikeSymbol(_Symbol);
   if(!isSpikeSym)
   {
      SMC_SpikeBlink_ClearWatchArrow();
      if(g_spikeBlink.state != SPIKE_BLINK_IDLE) SMC_SpikeBlink_Reset();
      return;
   }

   int native = SMC_SpikeBlink_NativeDir(_Symbol);
   if(native == 0)
   {
      SMC_SpikeBlink_ClearWatchArrow();
      if(g_spikeBlink.state != SPIKE_BLINK_IDLE) SMC_SpikeBlink_Reset();
      return;
   }

   SMC_SpikeBlink_UpdateWatchArrow(native);
   if(!UseSpikeBlinkDetector) return;
   SMCGP_RestoreAlignedGoodIfWait(_Symbol);

   if(CountPositionsForSymbol(_Symbol) > 0)
   {
      if(g_spikeBlink.state != SPIKE_BLINK_IDLE)
         SMC_SpikeBlink_Reset();
      return;
   }

   datetime ct = 0;
   double cpx = 0.0;
   bool liveSpike = SMC_SpikeBlink_LiveCandle(native, ct, cpx);

   int vn = SMC_SpikeBlink_EffectiveVn();
   int vnSign = (vn > 0) ? 1 : ((vn < 0) ? -1 : 0);
   bool weakForecastConflict = (g_smcSpikeHTFSimpleAllowed &&
                                g_smcForecast5mReady &&
                                g_smcForecastHorizonMinutes == 5 &&
                                MathAbs(g_smcGomVerdictForecastNum) == 1 &&
                                ((g_smcGomVerdictForecastNum > 0) ? 1 : -1) != native);
   bool gomOk = (!weakForecastConflict && g_smcGomConnected &&
                 MathAbs(vn) >= 2 && vnSign == native);
   bool tripleOk = SMC_SpikeBlink_TripleTFAligned(native);
   string overrideReason = "";
   bool htfWaitOk = (!gomOk &&
                     SMC_SpikeBlink_HTFWaitSetup(_Symbol, native, liveSpike, overrideReason));

   if((!gomOk && !htfWaitOk) || (!htfWaitOk && !tripleOk))
   {
      if(g_spikeBlink.state != SPIKE_BLINK_IDLE && g_spikeBlink.state != SPIKE_BLINK_FIRED)
         SMC_SpikeBlink_Reset();
      g_smcSpikeBlinkHTFDisplayDir = 0;
      SMC_SpikeBlink_LogBlocked(!gomOk && !htfWaitOk
         ? "GOM WAIT: " + overrideReason
         : "en attente de l'alignement M1/M5/M15");
      return;
   }

   double channelLevel = 0.0;
   string patternName = "";
   string contextReason = "";
   if(!htfWaitOk &&
      !SMC_SpikeBlink_ChannelPatternContext(native, channelLevel, patternName, contextReason))
   {
      if(g_spikeBlink.state != SPIKE_BLINK_IDLE && g_spikeBlink.state != SPIKE_BLINK_FIRED)
         SMC_SpikeBlink_Reset();
      SMC_SpikeBlink_LogBlocked(contextReason);
      return;
   }

double htfEntryPrice = (native > 0)
                           ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    // FIX: Always prefer channel/pattern level as target (pre-spike warning),
    // not the spike candle itself. The spike candle is the CONFIRMATION,
    // the channel/pattern level is the ORIGIN.
    double targetPrice = 0.0;
    string targetSource = "";
    bool hasChannelPattern = false;
    if(!htfWaitOk)
    {
       string dummyReason = "";
       hasChannelPattern = SMC_SpikeBlink_ChannelPatternContext(native, channelLevel, patternName, dummyReason);
    }
    if(hasChannelPattern && channelLevel > 0.0)
    {
       // Use channel/pattern level as target (pre-spike warning)
       targetPrice = channelLevel;
       targetSource = patternName;
    }
    else if(liveSpike)
    {
       // Fallback: spike detected but no channel/pattern context
       // Still use the channel boundary if available, otherwise spike price
       double chanBoundary = (native > 0) ? 
           SMC_TrendLineValueAt("SMC_Chan_Lower", TimeCurrent()) :
           SMC_TrendLineValueAt("SMC_Chan_Upper", TimeCurrent());
       if(chanBoundary > 0.0)
       {
          targetPrice = chanBoundary;
          targetSource = native > 0 ? "CHAN_LOWER" : "CHAN_UPPER";
       }
       else
       {
          targetPrice = cpx; // spike candle low/high as last resort
          targetSource = "M1_CANDLE";
       }
    }
    else
    {
       targetPrice = htfEntryPrice;
       targetSource = htfWaitOk ? (liveSpike ? "HTF_SPIKE" : "HTF_CHAIN") : "LIVE_PRICE";
    }
    if(!liveSpike && !htfWaitOk)
       ct = iTime(_Symbol, PERIOD_M1, 0);
   bool newSetup = (g_spikeBlink.state == SPIKE_BLINK_IDLE ||
                    g_spikeBlink.state == SPIKE_BLINK_FIRED ||
                    g_spikeBlink.dirSign != native ||
                    g_spikeBlink.targetSource != targetSource ||
                    g_spikeBlink.htfWaitOverride != htfWaitOk);
   if(g_spikeBlink.armedSince > 0 &&
      TimeCurrent() - g_spikeBlink.armedSince > MathMax(1, SpikeBlinkSetupMaxAgeMinutes) * 60)
   {
      SMC_SpikeBlink_Reset();
      SMC_SpikeBlink_LogBlocked("setup expiré; attente d'un nouveau retest canal/pattern");
      return;
   }
   if(newSetup)
   {
      g_spikeBlink.armedSince = TimeCurrent();
      g_spikeBlink.blinkTransitions = 0;
      g_spikeBlink.blinkVisible = true;
      Print("[SPIKE-BLINK] SETUP ", (native > 0 ? "BUY" : "SELL"),
            " | ", targetSource,
            htfWaitOk
               ? " | GOM=WAIT→SIMPLE HTF D1/H4 alignés"
               : " | pattern=" + patternName +
                 " | canal=" + DoubleToString(channelLevel, _Digits) +
                 " | GOM=" + IntegerToString(vn) + " M1/M5/M15=OK");
   }
   g_spikeBlink.dirSign      = native;
   g_spikeBlink.targetPrice  = targetPrice;
   g_spikeBlink.barTime      = ct;
   g_spikeBlink.targetSource = targetSource;
   g_spikeBlink.htfWaitOverride = htfWaitOk;
   g_smcSpikeBlinkHTFDisplayDir = htfWaitOk ? native : 0;
   g_spikeBlink.state = (gomOk && MathAbs(vn) >= 3 && tripleOk)
                        ? SPIKE_BLINK_ARMED_STRONG
                        : (gomOk && tripleOk ? SPIKE_BLINK_ARMED_STRONG : SPIKE_BLINK_ARMED);

   SMC_SpikeBlink_Toggle();

   // Attendre que la flèche soit apparue et ait complété deux phases visibles.
   if((htfWaitOk || (gomOk && tripleOk)) &&
      g_spikeBlink.blinkTransitions >= 4 && g_spikeBlink.blinkVisible)
      SMC_SpikeBlink_TryFire();
   else
      SMC_SpikeBlink_LogBlocked("setup qualifié; attente du clignotement confirmé");
}

#endif
