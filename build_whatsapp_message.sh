#!/bin/bash

# Données TradingView
PRICE=4534.37
TIME_UTC="10:45"
DATE_UTC="29/05"
VWAP=4510.279
VWAP_DIFF=$(echo "4534.37 - 4510.279" | bc)
BB_UP=4534.216
BB_MID=4519.290
BB_DN=4504.365
ST_LINE=5368.544
ST_DIR="UP"
FIB_0=4539.750
FIB_382=4520.354

# GOM Verdict
VERDICT="PERFECT BUY"
SCORE_BUY=6.2
SCORE_SELL=0.7
SPIKE_PCT=6
RSI=68
COHERENCE=83
QUALITY=44

# Multi-TF
TF_BULL_COUNT=5
TF_BEAR_COUNT=1

# Session Bias
BIAS_DIR="BUY"
BIAS_CONF=90
BIAS_VALID_H=20.92

# EA Order
ORDER_ACTION="BUY"
ORDER_ENTRY=4536.38
ORDER_CONF=88
ORDER_STATUS="READY"

# TA Report
TA_STATUS="NONE (no active order)"

# Confluence analysis
CONFLUENCE="✅ GOM PERFECT BUY + Biais BUY 90% + Prix > VWAP + Multi-TF BULL"
DECISION="🟢 BUY IMMÉDIAT — confluence maximale"

# Build message
MESSAGE="📊 TradBOT [$TIME_UTC UTC]

*XAUUSD — Suivi 20min* | $DATE_UTC $TIME_UTC UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* \$$PRICE
📍 VWAP : \$$VWAP → prix AU-DESSUS (+\$$VWAP_DIFF)
📊 BB : [\$$BB_DN / \$$BB_MID / \$$BB_UP] → EN HAUT de la zone
⚡ Supertrend : \$$ST_LINE ($ST_DIR) → AU-DESSUS
📐 Fibo : \$$FIB_0 (R0) / \$$FIB_382 (S1)
━━━━━━━━━━━━━━━━━━━━
🟢 *Verdict GOM KOLA : $VERDICT*
   Score BUY=$SCORE_BUY  SELL=$SCORE_SELL  Spike=$SPIKE_PCT%
   RSI=$RSI | ST=$ST_DIR | Coherence=$COHERENCE%
━━━━━━━━━━━━━━━━━━━━
🟢 *Biais session :* $BIAS_DIR $BIAS_CONF% | ✅ valide $BIAS_VALID_H h
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* 🟢 $ORDER_ACTION market @ \$$ORDER_ENTRY | Conf $ORDER_CONF% | $ORDER_STATUS
   SL: — | TP: —
━━━━━━━━━━━━━━━━━━━━
❌ *Rapport TradingAgents :* $TA_STATUS
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
  $CONFLUENCE
  ✅ Multi-TF : $TF_BULL_COUNT BULL / $TF_BEAR_COUNT BEAR → Tendance haussière dominante
  ✅ Setup qualité: $QUALITY% (modéré)
🎯 *Décision scalping*
  $DECISION
  EL: $ORDER_ENTRY-$BB_UP | SL: $BB_DN | TP1: $FIB_0 | TP2: 4545
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"

# Save to file
echo "$MESSAGE" > /tmp/whatsapp_message.txt

# Display
echo "$MESSAGE"
