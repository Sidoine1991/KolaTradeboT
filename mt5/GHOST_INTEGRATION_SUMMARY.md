# DerivEAPro v10 — GHOST OrderFlow Integration Summary

## Version
- **Old**: DerivEAPro v9 (ICT/SMC only)
- **New**: DerivEAPro v10 (ICT/SMC + GHOST OrderFlow)

## 10 Integration Blocs Implemented

### BLOC 1: Include (Line 23)
```mql5
#include "GOMVerdict.mqh"  // ← BLOC 1: Include GHOST signal parser
```
**Purpose**: Load GHOST signal parser library

---

### BLOC 2: Input Parameters (Lines 84-89)
```mql5
input group "=== GHOST ORDERFLOW ==="
input bool   InpUseGHOST         = false;        // Activer GHOST OrderFlow
input string InpGHOSTFile        = "gom_signal.json";
input int    InpGHOSTPollSec     = 5;            // Poll interval (secondes)
input double InpGHOSTMinQuality  = 40.0;         // Qualité minimum (%)
input int    InpGHOSTMaxAgeSec   = 60;           // Timeout données stale (s)
```
**Purpose**: Configuration inputs for GHOST feature

---

### BLOC 3: Global State (Lines 164-166)
```mql5
SGOMSignal g_ghost;
datetime   g_lastGHOSTPoll = 0;
```
**Purpose**: Global variables to store GHOST data

---

### BLOC 4: Polling Function (Lines 177-197)
```mql5
void PollGHOST()
{
   if(!InpUseGHOST) return;
   if((int)(TimeCurrent() - g_lastGHOSTPoll) < InpGHOSTPollSec) return;
   g_lastGHOSTPoll = TimeCurrent();
   // ... read signal file and parse ...
}
```
**Purpose**: Poll gom_signal.json every N seconds for GHOST data

---

### BLOC 5: GHOST Filter in EvaluateEntry() (Lines 606-633)
```mql5
if(InpUseGHOST)
{
   // Check signal age and quality
   // Verify verdict aligns with direction
   // REJECT if mismatch
}
```
**Purpose**: Gate entry if GHOST sentiment opposes signal

---

### BLOC 7a: Update Reason (ANTICIPATION) (Lines 655-661)
```mql5
reason = StringFormat("ANTICIPATION %.0f%% | ICT=%d(%s)%s | RSI=%.0f | ...",
                     sp.cyclePct*100, ict.Score, ict.Grade,
                     InpUseGHOST ? " + GHOST=" + g_ghost.verdict : "",
                     rsi, ...);
```
**Purpose**: Log GHOST verdict in trade reason

---

### BLOC 7b: Update Reason (PULLBACK) (Lines 690-695)
```mql5
reason = StringFormat("PULLBACK post-spike %d bars | ICT=%d(%s)%s | RSI=%.0f | dist=%.5f",
                     barsSince, ict.Score, ict.Grade,
                     InpUseGHOST ? " + GHOST=" + g_ghost.verdict : "",
                     rsi, distFromSpike);
```
**Purpose**: Log GHOST verdict in pullback reason

---

### BLOC 8: Dashboard Display (Lines 1043-1052)
```mql5
if(InpUseGHOST && g_ghost.valid)
{
   int age = (int)(TimeCurrent() - g_ghost.loadedAt);
   color gc = (g_ghost.verdict == "BUY" || g_ghost.verdict == "STRONG_BUY") ? clrLimeGreen :
              (g_ghost.verdict == "SELL" || g_ghost.verdict == "STRONG_SELL") ? clrRed :
              clrYellow;
   DashLabel("T4b", StringFormat("GHOST %-10s Q=%.0f%% [%ds]",
             g_ghost.verdict, g_ghost.quality, age),
             y, gc, 9);
   y += s;
}
```
**Purpose**: Display GHOST signal on chart dashboard

---

### BLOC 9: Initialize GHOST (Lines 1162-1168)
```mql5
g_ghost.verdict = "WAIT";
g_ghost.valid = false;
if(InpUseGHOST) {
   PollGHOST();
   PrintFormat("[v9] GHOST OrderFlow activé | MinQuality=%.0f%% | MaxAge=%ds",
               InpGHOSTMinQuality, InpGHOSTMaxAgeSec);
}
```
**Purpose**: Initialize GHOST system on EA startup

---

### BLOC 10: Poll in OnTick() (Line 1237)
```mql5
PollGHOST();
```
**Purpose**: Update GHOST data every tick (respects poll interval)

---

## Architecture

```
TradingView Data (gom_signal.json)
  └─ Contains: ghost_delta, ghost_cvd, ghost_compass, 
              ghost_buypct, ghost_sellpct, ghost_available
     
        ↓ (poll every 5s via PollGHOST())

EvaluateEntry() Decision Tree
  1. GHOST Filter (NEW) ← BLOC 5
     ├─ Check signal age + quality
     └─ REJECT if verdict opposes direction
  
  2. RSI Filter (existing)
  
  3. ICT Filter (existing)
  
  4. ANTICIPATION mode (BLOC 7a)
     └─ Log GHOST verdict in reason
  
  5. PULLBACK mode (BLOC 7b)
     └─ Log GHOST verdict in reason

      ↓ (on trade)

Dashboard (BLOC 8)
  └─ Display GHOST sentiment + quality + age
```

---

## Usage

### Enable GHOST OrderFlow:
1. In EA Inputs: `InpUseGHOST = true`
2. Ensure `gom_signal.json` file is updated by Python pipeline
3. Quality minimum: `InpGHOSTMinQuality = 40.0%`
4. Poll interval: `InpGHOSTPollSec = 5` seconds
5. Data timeout: `InpGHOSTMaxAgeSec = 60` seconds

### Configuration Example (Strict):
```
InpUseGHOST = true
InpGHOSTMinQuality = 60.0  // Require high quality
InpGHOSTMaxAgeSec = 30     // Fresh data only
InpMinICTScore = 50        // ICT + GHOST gate combined
```

### Configuration Example (Loose):
```
InpUseGHOST = true
InpGHOSTMinQuality = 20.0  // Lower threshold
InpGHOSTMaxAgeSec = 120    // Tolerate older data
InpMinICTScore = 0         // GHOST gates alone
```

---

## Impact

✅ **Reduces False Signals**: GHOST divergence blocks orders when sentiment opposes price
✅ **Increases Confluence**: Triple gate (Spike + ICT + GHOST) for stronger entries
✅ **OrderFlow Awareness**: Detects extreme delta/CVD for spike anticipation
✅ **Backward Compatible**: Set `InpUseGHOST = false` to run v10 like v9

---

## Testing

```mql5
// On any Boom/Crash chart M1, attach EA with:
InpUseGHOST = true;
InpMinICTScore = 40;  // Moderate gate

// Monitor dashboard:
// ├─ ICT score + components
// └─ GHOST sentiment + quality + age

// Expected: GHOST panel appears when data is fresh
// Expected: Entries blocked if GHOST verdict opposes direction
```

---

## Files Modified

- `D:\Dev\TradBOT\mt5\deriveapro.mq5` → **v10.00** (main EA with GHOST)
- `D:\Dev\TradBOT\mt5\GOMVerdict.mqh` → **required** (signal parser)
- `D:\Dev\TradBOT\data\gom_signal.json` → **required** (signal source)

---

## Version History

| Version | Changes |
|---------|---------|
| v9.00 | ICT/SMC spike detection, hybrid entry mode |
| v10.00 | + GHOST OrderFlow integration (delta, CVD, sentiment, compass) |

---

**Status**: ✅ READY FOR COMPILATION & DEPLOYMENT

Generated: 2026-06-06 16:25 UTC
