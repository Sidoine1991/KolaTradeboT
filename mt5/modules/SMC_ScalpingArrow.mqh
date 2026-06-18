//+------------------------------------------------------------------+
//| SMC_ScalpingArrow.mqh - Simplified scalping arrow module
//| Shows entry opportunity when ALL gates pass + signal valid
//+------------------------------------------------------------------+

#ifndef __SMC_SCALPING_ARROW__
#define __SMC_SCALPING_ARROW__

struct ScalpingArrowState {
   bool isActive;
   bool isBlinking;
   datetime lastBlink;
   int barsInSmallCandles;
   bool spikeDetected;
   double entryPrice;
   double stopLoss;
   double takeProfit1;
   double takeProfit2;
   double takeProfit3;
};

class ScalpingArrowManager {
private:
   ScalpingArrowState state;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   int BLINK_INTERVAL_MS;
   double SPIKE_SIZE_MULTIPLIER;

public:
   ScalpingArrowManager(string sym, ENUM_TIMEFRAMES tf) {
      symbol = sym;
      timeframe = tf;
      BLINK_INTERVAL_MS = 300;
      SPIKE_SIZE_MULTIPLIER = 4.0;
      ResetState();
   }

   void ResetState() {
      state.isActive = false;
      state.isBlinking = false;
      state.barsInSmallCandles = 0;
      state.spikeDetected = false;
      state.entryPrice = 0;
      state.stopLoss = 0;
      state.takeProfit1 = 0;
      state.takeProfit2 = 0;
      state.takeProfit3 = 0;
   }

   void ActivateArrow(
      double entry,
      double sl,
      double tp1,
      double tp2,
      double tp3,
      string direction
   ) {
      state.isActive = true;
      state.isBlinking = true;
      state.lastBlink = TimeCurrent();
      state.entryPrice = entry;
      state.stopLoss = sl;
      state.takeProfit1 = tp1;
      state.takeProfit2 = tp2;
      state.takeProfit3 = tp3;
      state.barsInSmallCandles = 0;
      state.spikeDetected = false;

      Print("ARROW ACTIVATED - ", symbol, " | Direction: ", direction);
      Print("   Entry: ", DoubleToString(entry, _Digits),
            " | SL: ", DoubleToString(sl, _Digits));
   }

   void DeactivateArrow(string reason) {
      state.isActive = false;
      state.isBlinking = false;
      state.barsInSmallCandles = 0;
      Print("ARROW DEACTIVATED - ", symbol, " | Reason: ", reason);
   }

   void DrawBlinkingArrow(MqlRates &rates[], int bars) {
      if(!state.isActive) return;

      int blinkPhase = (int)((TimeCurrent() - state.lastBlink) * 1000 / BLINK_INTERVAL_MS) % 2;

      if(blinkPhase == 0) {
         string labelText = StringFormat("TP1: %.2f | TP2: %.2f | TP3: %.2f",
                                        state.takeProfit1,
                                        state.takeProfit2,
                                        state.takeProfit3);
         Print("Arrow blinking: ", labelText);
      }
   }

   bool DetectSpike(MqlRates &rates[], int bars, double atr) {
      if(bars < 2) return false;

      double lastMove = MathAbs(rates[0].high - rates[0].low);

      if(lastMove > atr * SPIKE_SIZE_MULTIPLIER) {
         state.spikeDetected = true;
         DeactivateArrow("SPIKE DETECTED");
         return true;
      }

      return false;
   }

   bool TrackSmallCandles(MqlRates &rates[], int bars, double atr) {
      if(!state.spikeDetected) return false;
      if(bars < 5) return false;

      int smallCount = 0;
      for(int i = 0; i < 4; i++) {
         double size = MathAbs(rates[i].high - rates[i].low);
         if(size < atr * 0.5) {
            smallCount++;
         }
      }

      if(smallCount >= 3) {
         state.spikeDetected = false;
         state.isActive = true;
         state.isBlinking = true;
         state.lastBlink = TimeCurrent();

         Print("ARROW RE-ACTIVATED - Signal still valid after spike");
         return true;
      }

      return false;
   }

   string FormatEntryNotification(string direction, string pattern) {
      string msg = "";

      msg += "ENTRY SIGNAL READY\n";
      msg += "═══════════════════════════════════\n\n";

      msg += StringFormat("Symbol: %s\n", symbol);
      msg += StringFormat("Direction: %s (%s)\n\n", direction, pattern);

      msg += "ENTRY LEVELS\n";
      msg += StringFormat("Entry: %.2f\n", state.entryPrice);
      msg += StringFormat("Stop Loss: %.2f\n", state.stopLoss);
      msg += StringFormat("Risk/Reward: %.2f\n\n",
         MathAbs(state.takeProfit1 - state.entryPrice) /
         MathAbs(state.entryPrice - state.stopLoss));

      msg += "TAKE PROFIT TARGETS\n";
      msg += StringFormat("TP1 (50%%): %.2f (Exit 50%% here)\n", state.takeProfit1);
      msg += StringFormat("TP2 (30%%): %.2f (Trail SL to entry)\n", state.takeProfit2);
      msg += StringFormat("TP3 (20%%): %.2f (Let it run)\n\n", state.takeProfit3);

      msg += "SCALP MODE\n";
      msg += "Arrow blinking on chart\n";
      msg += "Disappears if spike captured\n";
      msg += "Reappears after 3-4 small candles\n";
      msg += "Signal stays valid in trend\n";

      return msg;
   }

   string FormatExitNotification(string reason) {
      string msg = "";

      msg += "EXIT SIGNAL\n";
      msg += "═══════════════════════════════════\n\n";

      msg += StringFormat("Symbol: %s\n", symbol);
      msg += StringFormat("Reason: %s\n\n", reason);

      if(StringFind(reason, "Correction") >= 0) {
         msg += "CORRECTION IMMINENTE DETECTED\n";
         msg += "Correction in ~5 minutes\n";
         msg += "Risk increases significantly\n";
         msg += "Exit recommended now\n";
      }

      msg += "\nEXIT NOW\n";
      msg += "Close at current market\n";
      msg += "Take last TP if available\n";

      return msg;
   }

   void SendNotification(string msgType, string extraData = "") {
      string msg = "";

      if(msgType == "ENTRY") {
         msg = FormatEntryNotification(extraData, "Signal validated");
      } else if(msgType == "EXIT") {
         msg = FormatExitNotification(extraData);
      }

      if(msg != "") {
         Print("[SCALP-NOTIFICATION] ", msg);
      }
   }

   bool CheckCorrectionExit(bool isAnticipated, int barsUntil) {
      if(!state.isActive) return false;

      if(isAnticipated && barsUntil <= 5) {
         DeactivateArrow("CORRECTION IMMINENT (EXIT NOW)");
         SendNotification("EXIT", "Correction in ~5 bars");
         return true;
      }

      return false;
   }

   ScalpingArrowState GetState() {
      return state;
   }
};

#endif
