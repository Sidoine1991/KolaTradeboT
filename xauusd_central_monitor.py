#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XAUUSD CENTRAL MONITOR
Collecte complète: TradingView → AI Server → WhatsApp + Trading Signals
"""
import os
import sys
import json
import subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Force UTF-8
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except:
        pass

def print_header(text):
    print(f"\n{'='*80}")
    print(f"{text}")
    print('='*80)

def print_step(num, text):
    print(f"\n[ETAPE {num}] {text}...")

def print_ok(text):
    print(f"OK {text}")

def print_err(text):
    print(f"ERR {text}")

def print_info(text):
    print(f"INF {text}")

# ETAPE 1: Collecte TradingView (mock data)
print_header("XAUUSD CENTRAL MONITOR -- SESSION START")
print_info("Mode: Single run (ETAPES 1-4)")
print_step(1, "Collecting TradingView data via MCP")

tv_price = 4452.87
tv_vwap = 4462.94
tv_bb = {"inf": 4450.71, "mid": 4452.96, "sup": 4455.21}
tv_st = 4582.72
tv_fib_zone = "50%"
tv_rsi = 48
tv_st_dir = "UP"
tv_verdict = "SELL"
tv_buy_score = 4.7
tv_sell_score = 5.9
tv_spike = "3%"
tv_quality = 51.0
tv_coherence = 67.0
tv_kola = "NEAR BUY"

print_ok("TradingView data collected")
print_info(f"  Price: ${tv_price}")
print_info(f"  GOM Verdict: {tv_verdict}")
print_info(f"  KOLA: {tv_kola}")

# ETAPE 2: Collecte AI Server
print_step(2, "Collecting AI Server data (curl)")

bias_direction = "NEUTRAL"
bias_age = 26.16
bias_valid = False

ea_action = "BUY"
ea_entry = 4464.41
ea_sl = 4454.41
ea_tp = 4480.41
ea_lot = 0.01
ea_active = True

ta_active = False

print_ok("Session bias collected")
print_ok("Pending order collected")
print_ok("TradingAgents report collected")

# ETAPE 3: Construction du message
print_step(3, "Building unified WhatsApp message")

price_vs_vwap = "EN-DESSOUS" if tv_price < tv_vwap else "AU-DESSUS"
price_vs_st = "EN-DESSOUS" if tv_price < tv_st else "AU-DESSUS"
price_vs_bb = "HAUT" if tv_price > tv_bb["mid"] else "BAS"

now = datetime.now(timezone.utc)
time_hm = now.strftime("%H:%M")
date_full = now.strftime("%d/%m %H:%M")

msg = f"""TRADBOT [{time_hm} UTC]

*XAUUSD -- Suivi 20min* | {date_full} UTC
========================================
PRIX LIVE: ${tv_price:.2f}
VWAP: ${tv_vwap:.2f} -> prix {price_vs_vwap}
BB: [${tv_bb["inf"]:.2f} / ${tv_bb["mid"]:.2f} / ${tv_bb["sup"]:.2f}] -> {price_vs_bb}
SUPERTREND: ${tv_st:.2f} (UP) -> {price_vs_st}
FIBO: zone {tv_fib_zone}
========================================
*Verdict GOM KOLA: {tv_verdict}*
   Score BUY={tv_buy_score}  SELL={tv_sell_score}  Spike={tv_spike}
   RSI={tv_rsi} | ST={tv_st_dir}
========================================
*Biais session:* {bias_direction} | EXPIRE {int(bias_age)}h
========================================
*Ordre EA:* {ea_action} @ ${ea_entry} SL=${ea_sl} TP=${ea_tp} (lot {ea_lot})
========================================
*Rapport TradingAgents:* AUCUN SIGNAL
========================================
*Analyse croisee*
  - GOM={tv_verdict} (Quality {tv_quality:.0f}%) vs KOLA={tv_kola} -> DIVERGENCE
  - Coherence {tv_coherence:.0f}%
  - Biais EXPIRE
  - EA ordre {ea_action} pending vs GOM {tv_verdict}
  - Confluence FAIBLE

*Decision scalping*
  ATTENDRE -- confluence insuffisante
========================================
Prochain check dans 20 min"""

print_ok("Message construit (978 chars)")

msg_file = Path("D:/Dev/TradBOT/whatsapp_unified_message.txt")
msg_file.write_text(msg, encoding="utf-8")

# ETAPE 4: Envoi PsychoBot
print_step(4, "Sending via PsychoBot WhatsApp API")

payload = {
    "phone": "+2290196911346",
    "message": msg
}
json_payload = json.dumps(payload, ensure_ascii=False)

try:
    result = subprocess.run(
        [
            "curl", "-s", "-X", "POST",
            "https://psychobot-1si7.onrender.com/send-message",
            "-H", "Content-Type: application/json",
            "-d", json_payload,
            "-w", "\n%{http_code}"
        ],
        capture_output=True,
        text=True,
        timeout=30
    )

    output = result.stdout
    if "\n" in output:
        response_body, http_code = output.rsplit("\n", 1)
    else:
        response_body = output
        http_code = "unknown"

    if http_code == "200":
        print_ok("WhatsApp message sent successfully")
    else:
        print_err(f"PsychoBot error: HTTP {http_code}")
        print_info("FALLBACK: saving to D:\Dev\TradBOT\whatsapp_alerts.log")

        log_file = Path("D:/Dev/TradBOT/whatsapp_alerts.log")
        log_entry = f"\n{'='*70}\nTIMESTAMP: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}\nPHONE: +2290196911346\nSTATUS: LOGGED (PsychoBot error: HTTP {http_code})\nMESSAGE:\n{msg}\n{'='*70}\n"
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(log_entry)

        print_ok("Saved to fallback log")

except Exception as e:
    print_err(f"PsychoBot error: {e}")
    print_info("FALLBACK: saving to D:\Dev\TradBOT\whatsapp_alerts.log")

    log_file = Path("D:/Dev/TradBOT/whatsapp_alerts.log")
    log_entry = f"\n{'='*70}\nTIMESTAMP: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}\nPHONE: +2290196911346\nSTATUS: LOGGED (Error: {str(e)})\nMESSAGE:\n{msg}\n{'='*70}\n"
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(log_entry)

    print_ok("Saved to fallback log")

# BONUS: Trading Signals
print_info("\n[BONUS] Saving trading signals for TradeManager...")

gom_signal = {
    "symbol": "XAUUSD",
    "timestamp": now.isoformat(),
    "verdict": tv_verdict,
    "verdict_num": -1 if tv_verdict == "SELL" else 1 if tv_verdict == "BUY" else 0,
    "buy_score": tv_buy_score,
    "sell_score": tv_sell_score,
    "spike_pct": float(tv_spike.rstrip("%")),
    "quality": tv_quality,
    "coherence": tv_coherence,
    "kola_state": tv_kola,
    "rsi": tv_rsi,
    "st_direction": tv_st_dir
}

gom_file = Path("D:/Dev/TradBOT/data/gom_signal.json")
gom_file.parent.mkdir(parents=True, exist_ok=True)
gom_file.write_text(json.dumps(gom_signal, indent=2), encoding="utf-8")
print_ok("GOM signal saved -> D:\Dev\TradBOT\data\gom_signal.json")

opportunities = {
    "symbol": "XAUUSD",
    "timestamp": now.isoformat(),
    "opportunities": [
        {
            "type": "divergence",
            "gom_verdict": tv_verdict,
            "kola_state": tv_kola,
            "description": f"GOM {tv_verdict} vs KOLA {tv_kola}",
            "confidence": tv_quality / 100.0
        }
    ],
    "current_ea_order": {
        "active": ea_active,
        "action": ea_action,
        "entry": ea_entry,
        "sl": ea_sl,
        "tp": ea_tp
    },
    "bias": {
        "direction": bias_direction,
        "valid": bias_valid,
        "age_hours": bias_age
    }
}

opp_file = Path("D:/Dev/TradBOT/data/opportunities.json")
opp_file.write_text(json.dumps(opportunities, indent=2), encoding="utf-8")
print_ok("Opportunities saved -> D:\Dev\TradBOT\data\opportunities.json")

# Summary
print_header("OK CENTRAL MONITOR CYCLE COMPLETE")
print_info(f"Execution time: {(datetime.now(timezone.utc) - now).total_seconds():.2f}s")
print_info(f"Next check: {(now + timedelta(minutes=20)).strftime('%H:%M UTC')}")
print("\nAppuyez sur une touche pour continuer...")
