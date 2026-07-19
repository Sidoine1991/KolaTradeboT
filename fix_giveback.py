#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fix: Giveback Guard oscillation loop - add 30min cooldown after unlock."""

import sys, re

filepath = "D:\\Dev\\TradBOT\\mt5\\modules\\SMC_PerformancePause.mqh"

with open(filepath, "r", encoding="cp1252") as f:
    content = f.read()

e_acc = chr(130)

# 1. Add global variable after g_givebackLockTime
lines = content.split("\n")
found = False
for i, line in enumerate(lines):
    if "g_givebackLockTime" in line and "0;" in line and "Heure" in line:
        lines[i] = line + "\ndatetime g_givebackLockExpiredAt = 0;   // Timestamp du dernier d" + e_acc + "lock (cooldown 30min)"
        found = True
        break
if found:
    content = "\n".join(lines)
    print("1. Variable globale ajoutee")
else:
    print("1. ERREUR: variable globale non trouvee")
    sys.exit(1)

# 2. Replace the entire function
old_func_pattern = r"bool SMC_CheckProfitGivebackLock\(\)\s*\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*?\n\}"
match = re.search(old_func_pattern, content, re.DOTALL)
if match:
    old_func = match.group(0)
    new_func = '''bool SMC_CheckProfitGivebackLock()
{
   if(!UseProfitGivebackGuard)
      return false;

   // COOLDOWN 30min apres le dernier delock : empeche boucle expire/re-lock
   if(g_givebackLockExpiredAt > 0 && (TimeCurrent() - g_givebackLockExpiredAt) < 1800)
      return false;

   // AUTO-EXPIRY: verifier si les 2h sont ecoulees (tourne a chaque tick)
   if(g_profitGivebackLock && g_givebackLockTime > 0 && (TimeCurrent() - g_givebackLockTime) >= 7200)
   {
      g_profitGivebackLock = false;
      g_givebackLockTime   = 0;
      g_givebackLockExpiredAt = TimeCurrent();  // Marque le delock pour cooldown
      SMC_SavePerformancePauseState();
      Print("[GIVEBACK-GUARD] Pause 2h terminee -> trading autorise (cooldown 30min)");
      if(UseNotifications)
         SendNotification("Giveback guard: pause 2h terminee -> trading reactive");
      PB_SendWhatsAppAlert("GIVEBACK-GUARD TERMINE -> Trading reactive sur " + _Symbol);
      return false;
   }

   if(g_profitGivebackLock)
      return true;

   if(g_dailyStartEquity <= 0.0)
      return false;

   double peakProfit = g_dailyMaxEquity - g_dailyStartEquity;
   double curProfit  = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartEquity;

   if(peakProfit < ProfitGivebackMinPeakUSD)
   {
      if(g_dailyStartEquity > 0 && peakProfit < g_dailyStartEquity * 0.03)
         return false;
   }
   if(peakProfit <= 0.0)
      return false;

   double floorProfit = peakProfit * (1.0 - ProfitGivebackPct / 100.0);
   if(curProfit >= floorProfit)
      return false;

   g_profitGivebackLock = true;
   g_givebackLockTime   = TimeCurrent();
   g_givebackLockExpiredAt = 0;
   SMC_SavePerformancePauseState();
   Print("[GIVEBACK-GUARD] Pic jour +", DoubleToString(peakProfit, 2),
         "$ -> actuel +", DoubleToString(curProfit, 2),
         "$ (seuil ", DoubleToString(floorProfit, 2), "$) -> pause 2h");
    if(UseNotifications)
    {
       Alert("Giveback guard: pause 2h");
       SendNotification("Giveback guard: pause 2h -> reprise " + TimeToString(g_givebackLockTime + 7200, TIME_MINUTES));
    }
    PB_SendWhatsAppAlert(StringFormat("GIVEBACK-GUARD ACTIVE -> Pic +%.2f$ -> actuel +%.2f$ | Pause 2h",
          peakProfit, curProfit));
    return true;
}'''
    content = content.replace(old_func, new_func, 1)
    print("2. Fonction remplacee")
else:
    print("2. ERREUR: fonction non trouvee")
    sys.exit(1)

# 3. Update SavePerformancePauseState
old_save = 'GlobalVariableSet(SMC_PerfPauseGV("GivebackLockTime"),  (double)g_givebackLockTime);'
new_save = old_save + '\n   GlobalVariableSet(SMC_PerfPauseGV("GivebackLockExpiredAt"), (double)g_givebackLockExpiredAt);'
if old_save in content:
    content = content.replace(old_save, new_save, 1)
    print("3. Sauvegarde mise a jour")
else:
    print("3. ERREUR: sauvegarde non trouvee")

# 4. Update LoadPerformancePauseState
old_load = 'g_givebackLockTime = (datetime)GlobalVariableGet(SMC_PerfPauseGV("GivebackLockTime"));'
new_load = old_load + '\n   if(GlobalVariableCheck(SMC_PerfPauseGV("GivebackLockExpiredAt")))\n      g_givebackLockExpiredAt = (datetime)GlobalVariableGet(SMC_PerfPauseGV("GivebackLockExpiredAt"));'
if old_load in content:
    content = content.replace(old_load, new_load, 1)
    print("4. Chargement mis a jour")
else:
    print("4. ERREUR: chargement non trouve")

# 5. Update ResetPerformancePauseDaily (last occurrence only = ResetFull)
old_reset = 'GlobalVariableSet(SMC_PerfPauseGV("GivebackLockTime"), 0.0);'
new_reset = old_reset + '\n    GlobalVariableSet(SMC_PerfPauseGV("GivebackLockExpiredAt"), 0.0);'
count = content.count(old_reset)
if count >= 1:
    idx = content.rfind(old_reset)
    content = content[:idx] + new_reset + content[idx + len(old_reset):]
    print("5. Reset full mis a jour")
else:
    print("5. ERREUR: reset non trouve")

with open(filepath, "w", encoding="cp1252") as f:
    f.write(content)
print("Fichier mis a jour avec succes!")