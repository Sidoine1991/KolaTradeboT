#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Send unified XAUUSD report — collects TradingView + AI server data
Fallback: logs to whatsapp_alerts.log if PsychoBot unavailable
"""

import sys
import io
import json
import requests
from datetime import datetime
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# === DONNÉES COLLECTÉES ===
quote = {"price": 4540.53, "vwap": 4535.991, "bb_inf": 4539.571, "bb_mid": 4555.688, "bb_sup": 4571.806, "supertrend": 5368.544}
study = {"score_buy": 7.5, "score_sell": 2.1, "spike_pct": 13.0, "rsi": 58, "st_dir": "UP", "verdict": "PERFECT BUY", "coherence": 67, "quality": 58, "force": 5.4}
session_bias = {"direction": "NEUTRAL", "valid": False, "age_hours": 30.33}
pending_order = {"action": "BUY", "entry_price": 4534.405, "stop_loss": 4532.35, "take_profit": 4545.35, "confidence": 0.88}
tradingagents = {"ok": False}

# === FORMAT MESSAGE ===
now_utc = datetime.utcnow()
hh_mm = now_utc.strftime("%H:%M")
dd_mm = now_utc.strftime("%d/%m")

msg = f"""📊 TradBOT [{hh_mm} UTC]

*XAUUSD — Suivi 20min* | {dd_mm} {hh_mm} UTC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* ${quote['price']:.2f}
📍 VWAP : ${quote['vwap']:.2f} → AU-DESSUS
📊 BB : [{quote['bb_inf']:.0f} / {quote['bb_mid']:.0f} / {quote['bb_sup']:.0f}]
⚡ Supertrend : ${quote['supertrend']:.0f} ({study['st_dir']})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 BUY *Verdict GOM KOLA*
   Score BUY={study['score_buy']}  SELL={study['score_sell']}  Spike={study['spike_pct']:.0f}%
   RSI={study['rsi']} | ST={study['st_dir']} | Force={study['force']} pts
   Qualité={study['quality']}% | Cohérence={study['coherence']}%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ *Biais session :* NEUTRAL (EXPIRÉ -30h)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* BUY @ ${pending_order['entry_price']:.2f}
   SL: ${pending_order['stop_loss']:.2f} | TP: ${pending_order['take_profit']:.2f}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 *DÉCISION* : BUY PERFECT (88% confiance)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"""

print(msg)
print("\n" + "="*70)
print("TENTATIVE D'ENVOI VIA PSYCHOBOT")
print("="*70 + "\n")

# === ENVOI ===
try:
    resp = requests.post(
        "https://psychobot-1si7.onrender.com/send-message",
        json={"phone": "+2290196911346", "message": msg},
        timeout=10,
        verify=False
    )

    if resp.status_code in [200, 201]:
        print("✅ Message envoyé!")
        sys.exit(0)
    else:
        raise Exception(f"Status {resp.status_code}")

except Exception as e:
    print(f"❌ PsychoBot: {e}")
    print("📝 Fallback: Logging to whatsapp_alerts.log\n")

    log_file = Path("/d/Dev/TradBOT/whatsapp_alerts.log")
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(f"\n{'='*70}\n[{datetime.now().isoformat()}] XAUUSD Unified (Fallback)\n{'='*70}\n{msg}\n")

    print("✅ Message sauvegardé en fallback")
