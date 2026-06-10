//+------------------------------------------------------------------+
//| GOMVerdict.mqh — Lecture verdict GOM (JSON) + confluence locale  |
//+------------------------------------------------------------------+
#ifndef GOM_VERDICT_MQH
#define GOM_VERDICT_MQH

struct SGOMSignal
{
   string   verdict;
   int      verdictNum;
   double   buyScore;
   double   sellScore;
   double   spikePct;
   double   quality;
   double   coherence;
   string   kolaState;
   datetime loadedAt;
   bool     valid;
};

// Parse minimal JSON (champs gom_signal.json / webhook TV)
bool GOM_ParseJsonField(const string json, const string key, string &outVal)
{
   outVal = "";
   string needle = "\"" + key + "\"";
   int p = StringFind(json, needle);
   if(p < 0) return false;
   p = StringFind(json, ":", p);
   if(p < 0) return false;
   p++;
   while(p < StringLen(json) && (StringGetCharacter(json, p) == ' ' || StringGetCharacter(json, p) == '\t'))
      p++;
   if(p >= StringLen(json)) return false;
   ushort c = StringGetCharacter(json, p);
   if(c == '"')
   {
      p++;
      int q = StringFind(json, "\"", p);
      if(q < 0) return false;
      outVal = StringSubstr(json, p, q - p);
      return true;
   }
   int end = p;
   while(end < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, end);
      if(ch == ',' || ch == '}' || ch == '\n' || ch == '\r') break;
      end++;
   }
   outVal = StringSubstr(json, p, end - p);
   StringTrimLeft(outVal);
   StringTrimRight(outVal);
   return StringLen(outVal) > 0;
}

double GOM_ParseJsonDouble(const string json, const string key, double defVal = 0.0)
{
   string s;
   if(!GOM_ParseJsonField(json, key, s)) return defVal;
   return StringToDouble(s);
}

int GOM_ParseJsonInt(const string json, const string key, int defVal = 0)
{
   string s;
   if(!GOM_ParseJsonField(json, key, s)) return defVal;
   return (int)StringToInteger(s);
}

bool GOM_LoadSignalFromFile(const string relPath, SGOMSignal &sig)
{
   sig.valid = false;
   sig.verdict = "WAIT";
   sig.verdictNum = 0;
   sig.loadedAt = 0;

   int h = FileOpen(relPath, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
   {
      h = FileOpen(relPath, FILE_READ | FILE_TXT | FILE_ANSI);
      if(h == INVALID_HANDLE) return false;
   }

   string json = "";
   while(!FileIsEnding(h))
      json += FileReadString(h);
   FileClose(h);

   if(StringLen(json) < 10) return false;

   string v;
   if(GOM_ParseJsonField(json, "verdict", v)) sig.verdict = v;
   int vn = GOM_ParseJsonInt(json, "verdict_num", 0);
   if(vn == 0)
      vn = GOM_ParseJsonInt(json, "verdictNum", 0);
   sig.verdictNum = vn;
   sig.buyScore    = GOM_ParseJsonDouble(json, "buy_score", 0);
   sig.sellScore   = GOM_ParseJsonDouble(json, "sell_score", 0);
   sig.spikePct    = GOM_ParseJsonDouble(json, "spike_pct", 0);
   sig.quality     = GOM_ParseJsonDouble(json, "quality", 0);
   sig.coherence   = GOM_ParseJsonDouble(json, "coherence", 0);
   if(GOM_ParseJsonField(json, "kola_state", v)) sig.kolaState = v;

   sig.loadedAt = TimeCurrent();
   sig.valid = (StringLen(sig.verdict) > 0);
   return sig.valid;
}

// Confluence locale: OTE 61.8-78.6% + proximité pivot (KOLA simplifié)
bool GOM_PriceInOTERange(const string symbol, ENUM_TIMEFRAMES tf, int fibLb,
                         double price, double atr, double padMult)
{
   int need = fibLb + 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, need, rates) < need) return false;

   double hi = rates[0].high, lo = rates[0].low;
   for(int i = 0; i < fibLb && i < ArraySize(rates); i++)
   {
      if(rates[i].high > hi) hi = rates[i].high;
      if(rates[i].low < lo)  lo = rates[i].low;
   }
   double rng = hi - lo;
   if(rng <= 0) return false;
   double f618 = hi - 0.618 * rng;
   double f786 = hi - 0.786 * rng;
   double top = MathMax(f618, f786);
   double bot = MathMin(f618, f786);
   double pad = atr * padMult;
   return (price >= bot - pad && price <= top + pad);
}

bool GOM_CheckConfluence(const string symbol, ENUM_TIMEFRAMES tf, double price,
                         double atr, string &hitsOut)
{
   hitsOut = "";
   bool inOte = GOM_PriceInOTERange(symbol, tf, 50, price, atr, 0.35);
   if(inOte) hitsOut = "OTE";

   // Pivot low/high proche (KOLA simplifié, 3 barres)
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, tf, 1, 80, r) >= 20)
   {
      for(int i = 3; i < 60; i++)
      {
         bool pl = (r[i].low < r[i-1].low && r[i].low < r[i-2].low &&
                    r[i].low <= r[i+1].low && r[i].low <= r[i+2].low);
         bool ph = (r[i].high > r[i-1].high && r[i].high > r[i-2].high &&
                    r[i].high >= r[i+1].high && r[i].high >= r[i+2].high);
         if(pl && MathAbs(price - r[i].low) <= atr * 1.2)
         {
            if(StringLen(hitsOut) > 0) hitsOut += "+";
            hitsOut += "KOLA_BUY";
            break;
         }
         if(ph && MathAbs(price - r[i].high) <= atr * 1.2)
         {
            if(StringLen(hitsOut) > 0) hitsOut += "+";
            hitsOut += "KOLA_SELL";
            break;
         }
      }
   }
   return StringLen(hitsOut) > 0;
}

bool GOM_AllowsEntry(const SGOMSignal &sig, bool forBuy,
                     int minVerdictNum, double minQuality, bool useGate)
{
   if(!useGate) return true;
   // Fichier absent: ne pas bloquer (confluence locale + spike restent actifs)
   if(!sig.valid) return true;
   if(sig.quality < minQuality) return false;
   if(forBuy)  return (sig.verdictNum >= minVerdictNum);
   return (sig.verdictNum <= -minVerdictNum);
}

#endif
