//+------------------------------------------------------------------+
//| SMC_SmartMoneyVolume.mqh                                         |
//| Moteur SMV (Smart Money Volume) pour SMC_Universal.mq5           |
//| Autonome : n'utilise que des fonctions MQL5 natives.             |
//|                                                                  |
//| Principe (barre cloturee sur SMV_Timeframe, par defaut M1) :     |
//|  1) z-score du tick volume vs les SMV_ZLookback barres precedentes|
//|  2) IMPULSE  : z >= seuil ET corps >= SMV_MinBodyRatio du range   |
//|                (volume concentre dans le corps = smart money)     |
//|  3) ABSORB   : z >= seuil ET petit corps, au bord du range des    |
//|                SMV_AbsorbRangeBars barres, cloture du bon cote    |
//|                (absorption type VSA : achat au plus bas, vente    |
//|                au plus haut)                                      |
//|  4) FLOW     : flux de volume signe (position de cloture dans la  |
//|                barre x volume) sur SMV_FlowBars barres            |
//|  5) Score 0-100 ; signal valide si score >= SMV_MinScore et frais |
//|                                                                  |
//| Le declenchement de l'ordre est dans SMC_Universal.mq5           |
//| (SMC_TrySMVMarketEntry) : verdict GOM GOOD/PERFECT requis.       |
//+------------------------------------------------------------------+
#ifndef SMC_SMART_MONEY_VOLUME_MQH
#define SMC_SMART_MONEY_VOLUME_MQH

input group "=== SMART MONEY VOLUME (SMV) ==="
input bool            SMV_Enable            = true;      // Activer le moteur SMV
input bool            SMV_AutoTrade         = true;      // Ordre automatique si GOM GOOD/PERFECT + SMV aligne
input bool            SMV_ShadowOnly        = false;     // true = journalise les entrees sans passer d'ordre (validation)
input ENUM_TIMEFRAMES SMV_Timeframe         = PERIOD_M1; // Timeframe d'analyse SMV
input int             SMV_ZLookback         = 50;        // Barres pour moyenne/ecart-type du volume
input double          SMV_ZThreshold        = 1.5;       // Seuil z-score volume (outlier)
input double          SMV_MinBodyRatio      = 0.50;      // Corps/range mini pour IMPULSE
input int             SMV_AbsorbRangeBars   = 20;        // Fenetre du range pour l'absorption
input double          SMV_AbsorbMaxBody     = 0.35;      // Corps/range max pour ABSORB
input int             SMV_FlowBars          = 10;        // Barres pour le flux de volume signe
input double          SMV_MinFlowRatio      = 0.15;      // Flux mini dans le sens du signal (-1..+1)
input int             SMV_MinScore          = 60;        // Score mini (0-100) pour valider le signal
input int             SMV_SignalMaxAgeBars  = 3;         // Duree de validite du signal (en barres SMV)
input double          SMV_MaxChaseATR       = 1.0;       // Distance max prix/cloture du signal (x ATR), anti-chase
input int             SMV_CooldownSec       = 60;        // Delai mini entre deux entrees SMV
input bool            SMV_LogCsv            = true;      // Journal MQL5/Files/SMV_Log.csv

struct SMV_State
{
   int      dir;       // +1 BUY, -1 SELL, 0 aucun
   int      score;     // 0..100
   double   z;         // z-score du volume de la barre signal
   double   flow;      // flux de volume signe (-1..+1)
   double   sigClose;  // cloture de la barre signal
   datetime sigTime;   // heure d'ouverture de la barre signal
   string   kind;      // IMPULSE / ABSORB_LOW / ABSORB_HIGH
};

SMV_State g_smv;
datetime  g_smvLastBar = 0;
bool      g_smvInit    = false;

void SMV_ResetState()
{
   g_smv.dir      = 0;
   g_smv.score    = 0;
   g_smv.z        = 0.0;
   g_smv.flow     = 0.0;
   g_smv.sigClose = 0.0;
   g_smv.sigTime  = 0;
   g_smv.kind     = "";
   g_smvInit      = true;
}

void SMV_Log(const string eventName, const int dir, const string kind, const double z,
             const double flow, const int score, const string vn, const string note)
{
   if(!SMV_LogCsv) return;
   int h = FileOpen("SMV_Log.csv", FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI |
                    FILE_SHARE_READ | FILE_SHARE_WRITE, ';');
   if(h == INVALID_HANDLE) return;
   if(FileSize(h) == 0)
      FileWrite(h, "time", "symbol", "event", "dir", "kind", "z", "flow", "score", "gom_vn", "note");
   FileSeek(h, 0, SEEK_END);
   FileWrite(h, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), _Symbol, eventName, dir, kind,
             DoubleToString(z, 2), DoubleToString(flow, 3), score, vn, note);
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Recalcule le signal SMV a chaque nouvelle barre SMV_Timeframe    |
//+------------------------------------------------------------------+
void SMV_Refresh()
{
   if(!SMV_Enable) return;
   if(!g_smvInit) SMV_ResetState();

   datetime bar0 = iTime(_Symbol, SMV_Timeframe, 0);
   if(bar0 <= 0 || bar0 == g_smvLastBar) return;

   int lookZ = MathMax(10, SMV_ZLookback);
   int lookR = MathMax(5, SMV_AbsorbRangeBars);
   int lookF = MathMax(3, SMV_FlowBars);
   int need  = MathMax(lookZ, MathMax(lookR, lookF)) + 3;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, SMV_Timeframe, 0, need, r);
   if(got < need) return; // historique pas pret : on reessaie au tick suivant

   g_smvLastBar = bar0;

   // 1) z-score du volume de la derniere barre cloturee (shift 1)
   double sum = 0.0, sum2 = 0.0;
   int n = 0;
   for(int i = 2; i <= lookZ + 1; i++)
   {
      double v = (double)r[i].tick_volume;
      sum  += v;
      sum2 += v * v;
      n++;
   }
   if(n <= 0) return;
   double mean = sum / n;
   double var  = sum2 / n - mean * mean;
   double sd   = (var > 0.0) ? MathSqrt(var) : 0.0;
   double vol  = (double)r[1].tick_volume;
   double z    = (sd > 0.0) ? (vol - mean) / sd : 0.0;

   // 2) range des barres precedentes (pour l'absorption)
   double hi = r[2].high, lo = r[2].low;
   for(int i = 3; i <= lookR + 1; i++)
   {
      if(r[i].high > hi) hi = r[i].high;
      if(r[i].low  < lo) lo = r[i].low;
   }
   double zoneN = hi - lo;

   // 3) flux de volume signe sur les lookF dernieres barres cloturees
   double sumV = 0.0, sumVC = 0.0;
   for(int i = 1; i <= lookF; i++)
   {
      double rg = r[i].high - r[i].low;
      if(rg <= 0.0) continue;
      double clvI = ((r[i].close - r[i].low) - (r[i].high - r[i].close)) / rg;
      double vi   = (double)r[i].tick_volume;
      sumV  += vi;
      sumVC += vi * clvI;
   }
   double flow = (sumV > 0.0) ? sumVC / sumV : 0.0;

   // 4) classification de la barre signal
   double rng = r[1].high - r[1].low;
   int    dir = 0;
   string kind = "";
   if(rng > 0.0 && z >= SMV_ZThreshold)
   {
      double body = MathAbs(r[1].close - r[1].open);
      double br   = body / rng;
      double clv  = ((r[1].close - r[1].low) - (r[1].high - r[1].close)) / rng;
      if(br >= SMV_MinBodyRatio)
      {
         dir  = (r[1].close > r[1].open) ? 1 : -1;
         kind = "IMPULSE";
      }
      else if(br <= SMV_AbsorbMaxBody && zoneN > 0.0)
      {
         if(r[1].low <= lo + 0.25 * zoneN && clv > 0.2)
         {
            dir  = 1;
            kind = "ABSORB_LOW";
         }
         else if(r[1].high >= hi - 0.25 * zoneN && clv < -0.2)
         {
            dir  = -1;
            kind = "ABSORB_HIGH";
         }
      }
   }
   if(dir == 0) return; // pas de nouveau signal : l'ancien expire par age

   // 5) score
   bool aligned = (flow * dir >= SMV_MinFlowRatio);
   double sc = 40.0 + MathMin(30.0, MathMax(0.0, (z - SMV_ZThreshold) * 15.0));
   if(aligned) sc += MathMin(30.0, MathAbs(flow) / 0.5 * 30.0);
   int score = (int)MathMin(100.0, MathRound(sc));

   g_smv.dir      = dir;
   g_smv.score    = score;
   g_smv.z        = z;
   g_smv.flow     = flow;
   g_smv.sigClose = r[1].close;
   g_smv.sigTime  = r[1].time;
   g_smv.kind     = kind;

   Print("[SMV] ", _Symbol, " ", kind, " dir=", (dir > 0 ? "BUY" : "SELL"),
         " z=", DoubleToString(z, 2), " flow=", DoubleToString(flow, 2),
         " score=", score, (score >= SMV_MinScore ? " (valide)" : " (< seuil)"));
   SMV_Log("SIGNAL", dir, kind, z, flow, score, "", score >= SMV_MinScore ? "valid" : "below_min");
}

//+------------------------------------------------------------------+
//| Direction SMV active (0 si absent / expire / score trop bas)     |
//+------------------------------------------------------------------+
int SMV_SignalDir(int &score, string &kind)
{
   score = 0;
   kind  = "";
   if(!SMV_Enable || !g_smvInit || g_smv.dir == 0) return 0;
   long ps = (long)PeriodSeconds(SMV_Timeframe);
   if((long)(TimeCurrent() - g_smv.sigTime) > ps * (long)(SMV_SignalMaxAgeBars + 1)) return 0;
   if(g_smv.score < SMV_MinScore) return 0;
   score = g_smv.score;
   kind  = g_smv.kind;
   return g_smv.dir;
}

// Utilisable comme filtre de confluence par d'autres modules
bool SMV_ConfirmsDirection(const int dirSign)
{
   int sc = 0;
   string k = "";
   int d = SMV_SignalDir(sc, k);
   return (d != 0 && d == dirSign);
}

#endif // SMC_SMART_MONEY_VOLUME_MQH
