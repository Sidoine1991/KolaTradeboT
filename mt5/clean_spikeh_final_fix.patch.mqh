// ChannelDetection.mqh - shared channel detection and drawing utilities

#ifndef __CHANNEL_DETECTION_MQH__
#define __CHANNEL_DETECTION_MQH__

// Local defaults so this header works in any script/EA without external inputs
static const bool   CD_DrawChannels          = true;   // draw channels by default
static const int    CD_ChannelLookback       = 20;     // bars to confirm channel
static const double CD_ChannelConfirmRatio   = 0.6;    // min fraction of monotone HH/HL or LH/LL

bool IsDescendingChannel(MqlRates &rates[])
{
    int copied = ArraySize(rates);
    if (copied < CD_ChannelLookback) return false;
    
    int lower_highs = 0;
    int lower_lows = 0;
    int span = MathMin(CD_ChannelLookback, copied-1);
    for (int i = 1; i < span; i++) {
        if (rates[i].high < rates[i-1].high) lower_highs++;
        if (rates[i].low  < rates[i-1].low)  lower_lows++;
    }
    
    double need = CD_ChannelConfirmRatio * (span-1);
    return (lower_highs > need && lower_lows > need);
}

bool IsAscendingChannel(MqlRates &rates[])
{
    int copied = ArraySize(rates);
    if (copied < CD_ChannelLookback) return false;
    
    int higher_highs = 0;
    int higher_lows = 0;
    int span = MathMin(CD_ChannelLookback, copied-1);
    for (int i = 1; i < span; i++) {
        if (rates[i].high > rates[i-1].high) higher_highs++;
        if (rates[i].low  > rates[i-1].low)  higher_lows++;
    }
    
    double need = CD_ChannelConfirmRatio * (span-1);
    return (higher_highs > need && higher_lows > need);
}

void DrawChannelIfEnabled(const string namePrefix, color col)
{
    if(!CD_DrawChannels) return;
    MqlRates r[]; if(CopyRates(_Symbol, PERIOD_CURRENT, 0, CD_ChannelLookback+2, r) < CD_ChannelLookback+2) return;
    
    double maxH = r[1].high, minH = r[1].high;
    double maxL = r[1].low,  minL = r[1].low;
    for(int i=1;i<MathMin(CD_ChannelLookback, ArraySize(r)-1);i++){ maxH = MathMax(maxH, r[i].high); minH = MathMin(minH, r[i].high); maxL = MathMax(maxL, r[i].low); minL = MathMin(minL, r[i].low); }
    
    datetime t0 = r[CD_ChannelLookback].time;
    datetime t1 = r[1].time;
    string upName = StringFormat("%s_UP_%d", namePrefix, (int)TimeCurrent());
    string dnName = StringFormat("%s_DN_%d", namePrefix, (int)TimeCurrent());
    if(ObjectFind(0, upName)>=0) ObjectDelete(0, upName);
    if(ObjectFind(0, dnName)>=0) ObjectDelete(0, dnName);
    ObjectCreate(0, upName, OBJ_TREND, 0, t0, maxH, t1, minH);
    ObjectSetInteger(0, upName, OBJPROP_COLOR, col);
    ObjectCreate(0, dnName, OBJ_TREND, 0, t0, maxL, t1, minL);
    ObjectSetInteger(0, dnName, OBJPROP_COLOR, col);
}

#endif // __CHANNEL_DETECTION_MQH__


