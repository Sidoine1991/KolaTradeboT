//+------------------------------------------------------------------+
//| Loss Cooldown Manager — MT5 Module
//| Tracks consecutive losses per symbol and triggers 1-hour cooldown
//+------------------------------------------------------------------+

#ifndef _LOSS_COOLDOWN_MANAGER_MQH_
#define _LOSS_COOLDOWN_MANAGER_MQH_

#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>

//+------------------------------------------------------------------+
//| Cooldown Data Structure
//+------------------------------------------------------------------+
struct LossCooldownData
{
    string symbol;
    int consecutive_losses;
    datetime last_loss_time;
    datetime cooldown_until;
    double last_loss_amount;
    int loss_count;
};

//+------------------------------------------------------------------+
//| Loss Cooldown Manager Class
//+------------------------------------------------------------------+
class LossCooldownManager
{
private:
    LossCooldownData cooldowns[];
    int cooldown_duration_sec;
    int consecutive_loss_threshold;
    bool log_enabled;

public:
    // Constructor
    LossCooldownManager(int threshold = 2, int duration_min = 60, bool enable_log = true)
    {
        ArrayResize(cooldowns, 0);
        consecutive_loss_threshold = threshold;
        cooldown_duration_sec = duration_min * 60;
        log_enabled = enable_log;

        if(log_enabled)
            Print("[LossCooldown] Initialized: threshold=", threshold, " loss(es), duration=",
                  duration_min, " minutes");
    }

    // Record a loss
    void RecordLoss(string symbol, double loss_amount = 0)
    {
        int idx = FindSymbolIndex(symbol);

        if(idx == -1)
        {
            idx = ArraySize(cooldowns);
            ArrayResize(cooldowns, idx + 1);
            cooldowns[idx].symbol = symbol;
            cooldowns[idx].consecutive_losses = 0;
            cooldowns[idx].cooldown_until = 0;
            cooldowns[idx].loss_count = 0;
        }

        cooldowns[idx].consecutive_losses++;
        cooldowns[idx].last_loss_time = TimeCurrent();
        cooldowns[idx].last_loss_amount = loss_amount;
        cooldowns[idx].loss_count++;

        if(log_enabled)
            Print("[LossCooldown] ", symbol, ": Loss #", cooldowns[idx].consecutive_losses,
                  " recorded (amount: $", DoubleToString(loss_amount, 2), ")");

        // Check if cooldown should be triggered
        if(cooldowns[idx].consecutive_losses >= consecutive_loss_threshold)
            TriggerCooldown(idx);
    }

    // Record a win (resets counter)
    void RecordWin(string symbol)
    {
        int idx = FindSymbolIndex(symbol);

        if(idx != -1)
        {
            cooldowns[idx].consecutive_losses = 0;
            if(log_enabled)
                Print("[LossCooldown] ", symbol, ": Win! Loss counter reset to 0");
        }
    }

    // Check if symbol is in cooldown
    bool IsInCooldown(string symbol)
    {
        int idx = FindSymbolIndex(symbol);

        if(idx == -1)
            return false;

        datetime now = TimeCurrent();

        if(cooldowns[idx].cooldown_until > now)
        {
            int remaining_sec = (int)(cooldowns[idx].cooldown_until - now);
            int remaining_min = remaining_sec / 60;

            if(log_enabled)
                Print("[LossCooldown] ", symbol, ": IN COOLDOWN (", remaining_min, " minutes remaining)");

            return true;
        }

        // Cooldown expired - reset
        if(cooldowns[idx].cooldown_until > 0 && cooldowns[idx].cooldown_until <= now)
        {
            cooldowns[idx].cooldown_until = 0;
            cooldowns[idx].consecutive_losses = 0;

            if(log_enabled)
                Print("[LossCooldown] ", symbol, ": COOLDOWN EXPIRED - trading re-enabled");
        }

        return false;
    }

    // Get cooldown info
    LossCooldownData GetCooldownInfo(string symbol)
    {
        LossCooldownData empty_data;
        int idx = FindSymbolIndex(symbol);

        if(idx == -1)
            return empty_data;

        return cooldowns[idx];
    }

    // Get remaining cooldown time (seconds)
    int GetRemainingCooldownSec(string symbol)
    {
        int idx = FindSymbolIndex(symbol);

        if(idx == -1)
            return 0;

        datetime now = TimeCurrent();
        int remaining = (int)(cooldowns[idx].cooldown_until - now);

        return MathMax(0, remaining);
    }

    // Manually reset symbol
    void ResetSymbol(string symbol)
    {
        int idx = FindSymbolIndex(symbol);

        if(idx != -1)
        {
            cooldowns[idx].consecutive_losses = 0;
            cooldowns[idx].cooldown_until = 0;

            if(log_enabled)
                Print("[LossCooldown] ", symbol, ": Manually reset");
        }
    }

    // Destructor
    ~LossCooldownManager() { }

private:
    // Find symbol index in array
    int FindSymbolIndex(string symbol)
    {
        for(int i = 0; i < ArraySize(cooldowns); i++)
        {
            if(cooldowns[i].symbol == symbol)
                return i;
        }
        return -1;
    }

    // Trigger cooldown
    void TriggerCooldown(int idx)
    {
        cooldowns[idx].cooldown_until = TimeCurrent() + cooldown_duration_sec;

        if(log_enabled)
        {
            Print("[LossCooldown] 🔴 ", cooldowns[idx].symbol,
                  ": COOLDOWN TRIGGERED after ", consecutive_loss_threshold, " losses");
            Print("[LossCooldown]    Cooldown until: ",
                  TimeToString(cooldowns[idx].cooldown_until, TIME_DATE|TIME_MINUTES));
            Print("[LossCooldown]    NO TRADING for 1 HOUR");
        }
    }
};

#endif // _LOSS_COOLDOWN_MANAGER_MQH_
