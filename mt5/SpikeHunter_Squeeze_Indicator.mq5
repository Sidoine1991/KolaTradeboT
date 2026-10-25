//+------------------------------------------------------------------+
//|                                                SpikeHunter Squeeze|
//|                                  Custom Indicator (MQL5)          |
//+------------------------------------------------------------------+
#property copyright   "SpikeHunter"
#property link        ""
#property version     "1.00"
#property description "BBW/ATR/body_z/EMA direction + marqueurs squeeze→expansion"

#property indicator_separate_window
#property indicator_buffers 20
#property indicator_plots   10

// Plot 0: BB Width
#property indicator_label1  "BBW"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 1: ATR ratio (ATR14/ATR50)
#property indicator_label2  "ATR_ratio"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// Plot 2: body_z (z-score corps)
#property indicator_label3  "body_z"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMediumVioletRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

// Plot 3: dirEMA (1 / -1)
#property indicator_label4  "dirEMA"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLime
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

// Plot 4: BBW mean (long)
#property indicator_label5  "BBW_mean"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDodgerBlue
#property indicator_style5  STYLE_DASH
#property indicator_width5  1

// Plot 5: ExtremeCount (rolling)
#property indicator_label6  "ExtremeCount"
#property indicator_type6   DRAW_HISTOGRAM
#property indicator_color6  clrSlateGray
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2

// Plot 6: SignalUp (subwindow, blinking)
#property indicator_label7  "SignalUp"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrLime
#property indicator_style7  STYLE_SOLID
#property indicator_width7  2

// Plot 7: SignalDn (subwindow, blinking)
#property indicator_label8  "SignalDn"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrTomato
#property indicator_style8  STYLE_SOLID
#property indicator_width8  2

// Plot 8: EqHL flag
#property indicator_label9  "EqHL"
#property indicator_type9   DRAW_HISTOGRAM
#property indicator_color9  clrYellow
#property indicator_style9  STYLE_SOLID
#property indicator_width9  2

// Plot 9: FVG flag
#property indicator_label10  "FVG"
#property indicator_type10   DRAW_HISTOGRAM
#property indicator_color10  clrAqua
#property indicator_style10  STYLE_SOLID
#property indicator_width10  2

// Buffers de plots
double g_bbw[];
double g_atr_ratio[];
double g_body_z[];
double g_dir_ema[];
double g_bbw_mean[];
double g_extreme_count[];
double g_sig_up[];
double g_sig_dn[];
double g_eqhl_flag[];
double g_fvg_flag[];

// Buffers de flèches (optionnel, non plot)
double g_arrow_up[];
double g_arrow_dn[];
double g_flag_squeeze[];
double g_flag_expand[];

// Handles
int h_bands = INVALID_HANDLE;
int h_atr14 = INVALID_HANDLE;
int h_atr50 = INVALID_HANDLE;
int h_ema_fast = INVALID_HANDLE;
int h_ema_slow = INVALID_HANDLE;

// Inputs
input group "=== Paramètres ==="
input int      InpBBPeriod      = 20;
input double   InpBBDeviation   = 2.0;
input int      InpBodyZWindow   = 120;
input int      InpEMAFast       = 9;
input int      InpEMASlow       = 21;
input int      InpATRShort      = 14;
input int      InpATRLong       = 50;
input bool     InpShowArrows    = true;
input double   InpSqueezeFactor = 0.6;   // BBW < 0.6 * BBW_mean
input double   InpATRFactor     = 1.5;   // ATR_ratio >= 1.5
input double   InpBodyZThresh   = 2.5;   // body_z >= 2.5
input int      InpExtremeWindow = 30;    // bars
input int      InpExtremeMax    = 2;     // max extremes allowed
input int      InpEqualHLWindow = 20;    // bars (Equal High/Low)
input double   InpEqualHLTolerancePts = 20; // tolerance in points
input int      InpFVGLookback = 30;      // bars

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
  IndicatorSetString(INDICATOR_SHORTNAME, "SpikeHunter Squeeze");
  IndicatorSetInteger(INDICATOR_DIGITS, 5);

  SetIndexBuffer(0, g_bbw, INDICATOR_DATA);
  SetIndexBuffer(1, g_atr_ratio, INDICATOR_DATA);
  SetIndexBuffer(2, g_body_z, INDICATOR_DATA);
  SetIndexBuffer(3, g_dir_ema, INDICATOR_DATA);
  SetIndexBuffer(4, g_bbw_mean, INDICATOR_DATA);
  SetIndexBuffer(5, g_extreme_count, INDICATOR_DATA);
  SetIndexBuffer(6, g_sig_up, INDICATOR_DATA);
  SetIndexBuffer(7, g_sig_dn, INDICATOR_DATA);
  SetIndexBuffer(8, g_eqhl_flag, INDICATOR_DATA);
  SetIndexBuffer(9, g_fvg_flag, INDICATOR_DATA);
  ArraySetAsSeries(g_bbw, true);
  ArraySetAsSeries(g_atr_ratio, true);
  ArraySetAsSeries(g_body_z, true);
  ArraySetAsSeries(g_dir_ema, true);
  ArraySetAsSeries(g_bbw_mean, true);
  ArraySetAsSeries(g_extreme_count, true);
  ArraySetAsSeries(g_sig_up, true);
  ArraySetAsSeries(g_sig_dn, true);
  ArraySetAsSeries(g_eqhl_flag, true);
  ArraySetAsSeries(g_fvg_flag, true);

  // Empty values to avoid zero lines before warmup (plots 0..7)
  PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);

  // Arrow codes for plots 6/7
  PlotIndexSetInteger(6, PLOT_ARROW, 233);
  PlotIndexSetInteger(7, PLOT_ARROW, 234);
  PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  PlotIndexSetDouble(9, PLOT_EMPTY_VALUE, EMPTY_VALUE);

  // flèches (non affichées en plots, utilisées pour objets)
  SetIndexBuffer(10,  g_arrow_up,     INDICATOR_CALCULATIONS);
  SetIndexBuffer(11,  g_arrow_dn,     INDICATOR_CALCULATIONS);
  SetIndexBuffer(12, g_flag_squeeze, INDICATOR_CALCULATIONS);
  SetIndexBuffer(13, g_flag_expand,  INDICATOR_CALCULATIONS);
  ArraySetAsSeries(g_arrow_up, true);
  ArraySetAsSeries(g_arrow_dn, true);
  ArraySetAsSeries(g_flag_squeeze, true);
  ArraySetAsSeries(g_flag_expand, true);

  // Handles indicateurs internes
  h_bands    = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
  h_atr14    = iATR(_Symbol, PERIOD_CURRENT, InpATRShort);
  h_atr50    = iATR(_Symbol, PERIOD_CURRENT, InpATRLong);
  h_ema_fast = iMA(_Symbol, PERIOD_CURRENT, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
  h_ema_slow = iMA(_Symbol, PERIOD_CURRENT, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);

  if(h_bands==INVALID_HANDLE || h_atr14==INVALID_HANDLE || h_atr50==INVALID_HANDLE ||
     h_ema_fast==INVALID_HANDLE || h_ema_slow==INVALID_HANDLE)
  {
    Print("[SpikeHunter Squeeze] Erreur création handles");
    return(INIT_FAILED);
  }

  // Draw begin to skip warmup region
  int warmup = MathMax(MathMax(InpBodyZWindow, 50), MathMax(InpATRLong, InpBBPeriod));
  // Set draw begin explicitly for plots 0..7
  PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, warmup);
  PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, warmup);
  PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, warmup);
  PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, warmup);
  PlotIndexSetInteger(4, PLOT_DRAW_BEGIN, warmup);
  PlotIndexSetInteger(5, PLOT_DRAW_BEGIN, warmup);
  PlotIndexSetInteger(6, PLOT_DRAW_BEGIN, warmup);
  PlotIndexSetInteger(7, PLOT_DRAW_BEGIN, warmup);
  PlotIndexSetInteger(8, PLOT_DRAW_BEGIN, warmup);
  PlotIndexSetInteger(9, PLOT_DRAW_BEGIN, warmup);

  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  if(h_bands   != INVALID_HANDLE) IndicatorRelease(h_bands);
  if(h_atr14   != INVALID_HANDLE) IndicatorRelease(h_atr14);
  if(h_atr50   != INVALID_HANDLE) IndicatorRelease(h_atr50);
  if(h_ema_fast!= INVALID_HANDLE) IndicatorRelease(h_ema_fast);
  if(h_ema_slow!= INVALID_HANDLE) IndicatorRelease(h_ema_slow);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
  int start = MathMax(prev_calculated-1, 0);
  if(start < 0) start = 0;

  // Préparer buffers internes
  static double ubuf[], mbuf[], lbuf[]; ArraySetAsSeries(ubuf,true); ArraySetAsSeries(mbuf,true); ArraySetAsSeries(lbuf,true);
  static double atr14buf[], atr50buf[]; ArraySetAsSeries(atr14buf,true); ArraySetAsSeries(atr50buf,true);
  static double emafbuf[], emasbuf[]; ArraySetAsSeries(emafbuf,true); ArraySetAsSeries(emasbuf,true);

  // Copier nécessaire pour toute la fenêtre utile
  int need = rates_total - start;
  if(need < 1) return(rates_total);

  CopyBuffer(h_bands, 0, 0, need, ubuf);
  CopyBuffer(h_bands, 1, 0, need, mbuf);
  CopyBuffer(h_bands, 2, 0, need, lbuf);
  CopyBuffer(h_atr14, 0, 0, need, atr14buf);
  CopyBuffer(h_atr50, 0, 0, need, atr50buf);
  CopyBuffer(h_ema_fast, 0, 0, need, emafbuf);
  CopyBuffer(h_ema_slow, 0, 0, need, emasbuf);

  // Corps de chandelle: open/close
  static double openbuf[], closebuf[]; ArraySetAsSeries(openbuf,true); ArraySetAsSeries(closebuf,true);
  CopyOpen(_Symbol, PERIOD_CURRENT, 0, need, openbuf);
  CopyClose(_Symbol, PERIOD_CURRENT, 0, need, closebuf);

  // Calcul rolling pour body z-score, BBW mean et extreme count
  int w = MathMax(20, MathMin(240, InpBodyZWindow));
  int wBBW = 50;
  int wExt = MathMax(5, InpExtremeWindow);

  for(int i=start; i<rates_total; i++)
  {
    // skip warmup
    bool ready = (i <= rates_total - MathMax(MathMax(InpBodyZWindow, 50), MathMax(InpATRLong, InpBBPeriod)));
    double upper = (ArraySize(ubuf)>i)?ubuf[i]:0.0;
    double mid   = (ArraySize(mbuf)>i)?mbuf[i]:0.0;
    double lower = (ArraySize(lbuf)>i)?lbuf[i]:0.0;
    double bbw   = (mid>0)? (upper-lower)/mid : 0.0;

    double atr14 = (ArraySize(atr14buf)>i)?atr14buf[i]:0.0;
    double atr50 = (ArraySize(atr50buf)>i)?atr50buf[i]:0.0;
    double atr_ratio = (atr50>0)? atr14/atr50 : 0.0;

    // body z-score
    double body = MathAbs(((ArraySize(closebuf)>i)?closebuf[i]:0.0) - ((ArraySize(openbuf)>i)?openbuf[i]:0.0));
    double mean=0.0, var=0.0; int cnt=0;
    for(int k=0; k<w && (i+k)<rates_total; k++) { // window en avant car arrays en série inversée
      int idx=i+k;
      double b = MathAbs(((ArraySize(closebuf)>idx)?closebuf[idx]:0.0) - ((ArraySize(openbuf)>idx)?openbuf[idx]:0.0));
      mean += b; cnt++;
    }
    if(cnt>0) mean/=cnt;
    for(int k=0; k<w && (i+k)<rates_total; k++) {
      int idx=i+k;
      double b = MathAbs(((ArraySize(closebuf)>idx)?closebuf[idx]:0.0) - ((ArraySize(openbuf)>idx)?openbuf[idx]:0.0));
      var += MathPow(b-mean,2);
    }
    if(cnt>1) var/=(cnt-1);
    double bstd = MathSqrt(var);
    double body_z = (bstd>0)? (body-mean)/bstd : 0.0;

    double emaf = (ArraySize(emafbuf)>i)?emafbuf[i]:0.0;
    double emas = (ArraySize(emasbuf)>i)?emasbuf[i]:0.0;
    double dir  = (emaf>emas)? 1.0 : -1.0;

    // BBW rolling mean
    double bbw_mean = 0.0; int bbw_cnt=0;
    for(int k=0; k<wBBW && (i+k)<rates_total; k++) { bbw_mean += ((ArraySize(ubuf)>i+k && ArraySize(mbuf)>i+k && ArraySize(lbuf)>i+k && mbuf[i+k]>0)? (ubuf[i+k]-lbuf[i+k])/mbuf[i+k] : 0.0); bbw_cnt++; }
    if(bbw_cnt>0) bbw_mean/=bbw_cnt;

    // extremes rolling
    int extreme_count = 0;
    for(int k=0; k<wExt && (i+k)<rates_total; k++)
    {
      int idx=i+k;
      double b = MathAbs(((ArraySize(closebuf)>idx)?closebuf[idx]:0.0) - ((ArraySize(openbuf)>idx)?openbuf[idx]:0.0));
      double bmean=0.0, bvar=0.0; int bcnt=0;
      // local fast approx: compare to global z computed at idx? reuse body_z at idx when available
      double z_at_idx = 0.0;
      if(idx<=i) z_at_idx = body_z; else {
        // fallback simple threshold by relative body vs ema range
        z_at_idx = (bstd>0)? (b-mean)/bstd : 0.0;
      }
      if(z_at_idx >= InpBodyZThresh) extreme_count++;
    }

    if(ready)
    {
      g_bbw[i]         = bbw;
      g_atr_ratio[i]   = atr_ratio;
      g_body_z[i]      = body_z;
      g_dir_ema[i]     = dir;
      g_bbw_mean[i]    = bbw_mean;
      g_extreme_count[i]= (double)extreme_count;
    }
    else
    {
      g_bbw[i] = g_atr_ratio[i] = g_body_z[i] = g_dir_ema[i] = g_bbw_mean[i] = g_extreme_count[i] = EMPTY_VALUE;
    }

    // Marqueurs visuels + signaux subwindow (barre courante uniquement)
    if(i==0)
    {
      // Equal High/Low flags (window-based)
      double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      bool eqh=false, eql=false;
      if(rates_total>=InpEqualHLWindow+2){
        // compute on last window
        double hi_last=0, hi_prev=0, lo_last=0, lo_prev=0;
        hi_last = (ArraySize(ubuf)>0)?ubuf[0]:0.0; // proxy using bands upper as ref height
        lo_last = (ArraySize(lbuf)>0)?lbuf[0]:0.0;
        hi_prev = (ArraySize(ubuf)>1)?ubuf[1]:0.0;
        lo_prev = (ArraySize(lbuf)>1)?lbuf[1]:0.0;
        if(MathAbs(hi_last-hi_prev)<=InpEqualHLTolerancePts*pt) eqh=true;
        if(MathAbs(lo_last-lo_prev)<=InpEqualHLTolerancePts*pt) eql=true;
      }
      g_eqhl_flag[0] = (eqh||eql)? 1.0 : EMPTY_VALUE;

      // Simple FVG flags (using open/close approximation from current timeframe)
      bool fvg=false;
      if(rates_total>=3){
        double o0 = (ArraySize(openbuf)>0)?openbuf[0]:0.0;
        double c2 = (ArraySize(closebuf)>2)?closebuf[2]:0.0;
        double c0 = (ArraySize(closebuf)>0)?closebuf[0]:0.0;
        double o2 = (ArraySize(openbuf)>2)?openbuf[2]:0.0;
        if(c0 < o2 || o0 > c2) fvg=true;
      }
      g_fvg_flag[0] = fvg? 1.0 : EMPTY_VALUE;
      static double bbw_prev = 0.0;
      bool is_squeeze = (bbw_mean>0 && bbw < InpSqueezeFactor * bbw_mean);
      bool squeeze_to_expand = (bbw_prev>0 && bbw > 2.0*bbw_prev);
      bbw_prev = bbw;
      g_flag_squeeze[0] = is_squeeze ? 1.0 : 0.0;
      bool expansion_ok = (squeeze_to_expand && atr_ratio>=(InpATRFactor*0.9) && body_z>=(InpBodyZThresh*0.9) && extreme_count<= (InpExtremeMax+1));
      g_flag_expand[0] = expansion_ok ? 1.0 : 0.0;
      // Boom/Crash orientation
      string sym = _Symbol; StringToLower(sym);
      bool is_boom  = (StringFind(sym, "boom")  >= 0);
      bool is_crash = (StringFind(sym, "crash") >= 0);
      bool allow_up   = (is_boom || (!is_boom && !is_crash));
      bool allow_down = (is_crash || (!is_boom && !is_crash));
      // blinking toggle
      static bool blink = false;
      static datetime lastSec = 0;
      datetime nowSec = TimeCurrent();
      if(nowSec != lastSec){ blink = !blink; lastSec = nowSec; }
      // reset plots
      g_sig_up[0] = EMPTY_VALUE;
      g_sig_dn[0] = EMPTY_VALUE;
      if(expansion_ok)
      {
        // Subwindow markers aligned on BBW value
        if(dir>0 && allow_up)
        {
          if(blink) g_sig_up[0] = bbw; else g_sig_up[0] = EMPTY_VALUE;
        }
        if(dir<0 && allow_down)
        {
          if(blink) g_sig_dn[0] = bbw; else g_sig_dn[0] = EMPTY_VALUE;
        }
        // Optional main chart arrow
        if(InpShowArrows)
        {
          string name = StringFormat("SH_Arrow_%d", (int)TimeCurrent());
          double y = SymbolInfoDouble(_Symbol, SYMBOL_BID);
          int code = (dir>0)? 233 : 234;
          color col = (dir>0)? clrLime : clrTomato;
          if(ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), y))
          {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
            ObjectSetInteger(0, name, OBJPROP_COLOR, col);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_BACK, false);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
          }
        }
      }
    }
  }

  return(rates_total);
}

//+------------------------------------------------------------------+

