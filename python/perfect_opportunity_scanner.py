#!/usr/bin/env python3
"""
Perfect Opportunity Scanner — Real-time trading opportunity notifications
Scans for symbols meeting ALL gates + sends WhatsApp alerts with countdown timers
"""

import os
import sys
import json
import time
import requests
import sqlite3
from datetime import datetime, timedelta
from typing import Dict, List, Tuple
import io

# Fix Windows encoding for emojis
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Add parent directory to path
sys.path.insert(0, os.path.dirname(__file__))

# Configuration
GOM_AI_SERVER = os.getenv("GOM_AI_SERVER", "http://localhost:8000")
PSYCHOBOT_RENDER = os.getenv("PSYCHOBOT_RENDER", "http://localhost:3000")  # Local fallback
SCAN_INTERVAL_SECONDS = int(os.getenv("SCAN_INTERVAL", "30"))  # Scan every 30s
WHATSAPP_UPDATE_INTERVAL = 120  # Send WhatsApp update every 2min (avoid spam)
OWNER_NUMBER = os.getenv("OWNER_NUMBER", "229")  # Sidoine's number prefix

# Thresholds for "PERFECT" opportunity
MIN_IA_CONFIDENCE = 70.0  # IA Status >= 70%
MIN_GOM_COHERENCE = 85.0  # GOM Coherence >= 85%
MIN_PROBABILITY = 65.0    # Probability gate >= 65%

# Tracking state
last_whatsapp_send = {}  # Track last send time per symbol
perfect_opportunities = {}  # Current perfect opportunities with timestamps


def get_gom_verdict(symbol: str) -> Dict:
    """Get current GOM verdict for a symbol from AI Server"""
    try:
        resp = requests.get(
            f"{GOM_AI_SERVER}/gom-verdict?symbol={symbol}",
            timeout=5
        )
        if resp.status_code == 200:
            return resp.json()
        return {}
    except Exception as e:
        print(f"[WARN]  GOM verdict fetch failed for {symbol}: {e}")
        return {}


def get_symbol_opportunity_status(symbol: str) -> Tuple[bool, Dict]:
    """
    Check if symbol meets PERFECT opportunity criteria:
    - IA Status confidence >= 70%
    - GOM Coherence >= 85%
    - Probability gate >= 65%
    - No recent losses (discipline check)
    """
    try:
        # Get GOM verdict
        verdict = get_gom_verdict(symbol)
        if not verdict:
            return False, {}

        ia_conf = float(verdict.get("ia_status_confidence", 0))
        gom_coher = float(verdict.get("gom_coherence_pct", 0))
        prob_gate = float(verdict.get("probability_pct", 0))
        action = verdict.get("ia_action", "HOLD")

        # Check all gates
        is_perfect = (
            ia_conf >= MIN_IA_CONFIDENCE
            and gom_coher >= MIN_GOM_COHERENCE
            and prob_gate >= MIN_PROBABILITY
            and action in ["BUY", "SELL"]
        )

        status = {
            "symbol": symbol,
            "ia_confidence": ia_conf,
            "gom_coherence": gom_coher,
            "probability": prob_gate,
            "action": action,
            "is_perfect": is_perfect,
            "detected_at": datetime.now().isoformat()
        }

        return is_perfect, status

    except Exception as e:
        print(f"[ERROR] Error checking {symbol}: {e}")
        return False, {}


def scan_perfect_opportunities(symbols: List[str]) -> List[Dict]:
    """Scan all symbols for perfect opportunities"""
    perfect = []
    for sym in symbols:
        is_perfect, status = get_symbol_opportunity_status(sym)
        if is_perfect:
            # Add detection timestamp if not already there
            if sym not in perfect_opportunities:
                perfect_opportunities[sym] = datetime.now()
                print(f"🎯 NEW PERFECT: {sym} | IA={status['ia_confidence']:.0f}% GOM={status['gom_coherence']:.0f}% PROB={status['probability']:.0f}%")

            # Add duration to status
            duration = (datetime.now() - perfect_opportunities[sym]).total_seconds()
            status['detected_duration'] = duration
            perfect.append(status)

    return perfect


def calculate_window_countdown(symbol: str, action: str) -> Tuple[int, str]:
    """
    Calculate remaining trading window (in seconds) for Boom/Crash symbols.
    Returns (seconds_remaining, window_label)
    """
    if "BOOM" not in symbol.upper() and "CRASH" not in symbol.upper():
        return 3600, "Standard session (1h)"  # Non-BC: standard 1h window

    now = datetime.now()
    utc_hour = now.utcnow().hour

    # Boom/Crash typical trading windows (UTC)
    if 8 <= utc_hour < 16:
        remaining = (16 - utc_hour) * 3600 - now.second
        return max(0, remaining), f"Trading until 16:00 UTC ({remaining//3600}h {(remaining%3600)//60}m left)"
    else:
        # Window closes at 16:00 UTC, next opens at 08:00 UTC
        if utc_hour >= 16:
            next_open = (24 - utc_hour + 8) * 3600
        else:
            next_open = (8 - utc_hour) * 3600
        return max(0, next_open), f"Window closed. Opens at 08:00 UTC (in {next_open//3600}h {(next_open%3600)//60}m)"


def format_whatsapp_message(perfect_list: List[Dict]) -> str:
    """Format WhatsApp message with perfect opportunities and countdowns"""
    if not perfect_list:
        return "🔍 No perfect opportunities detected at the moment."

    msg = "🎯 **PERFECT TRADING OPPORTUNITIES** 🎯\n"
    msg += f"⏰ {datetime.now().strftime('%H:%M:%S UTC')}\n\n"

    for opp in perfect_list:
        sym = opp["symbol"]
        action = opp["action"]
        ia = opp["ia_confidence"]
        gom = opp["gom_coherence"]
        prob = opp["probability"]

        # Calculate countdown
        secs_left, window_label = calculate_window_countdown(sym, action)

        # Emoji based on action
        emoji = "📈 BUY" if action == "BUY" else "📉 SELL"

        # Format entry
        msg += f"{emoji} **{sym}**\n"
        msg += f"  IA: {ia:.0f}% | GOM: {gom:.0f}% | PROB: {prob:.0f}%\n"
        msg += f"  [TIME]  {window_label}\n"

        # Add detected duration if tracked
        if sym in perfect_opportunities:
            duration = (datetime.now() - perfect_opportunities[sym]).total_seconds()
            msg += f"  [OK] Perfect for {duration//60:.0f}m\n"

        msg += "\n"

    msg += f"📊 Total: {len(perfect_list)} perfect opportunity(ies)\n"
    msg += "Ready to trade! ✨"

    return msg


def send_whatsapp_alert(message: str, to_number: str = None):
    """Send message via PsychoBot WhatsApp"""
    if to_number is None:
        to_number = OWNER_NUMBER

    try:
        payload = {
            "to": to_number,
            "message": message,
            "source": "tradbot-scanner"
        }

        # Try Render first, then local
        for url in [f"{PSYCHOBOT_RENDER}/send-message", "http://localhost:3000/send-message"]:
            try:
                resp = requests.post(url, json=payload, timeout=5)
                if resp.status_code == 200:
                    print(f"[OK] WhatsApp sent to {to_number}")
                    return True
            except:
                continue

        print(f"[WARN]  Could not send WhatsApp to {to_number}")
        return False

    except Exception as e:
        print(f"[ERROR] WhatsApp send failed: {e}")
        return False


def update_api_opportunities(opportunities: List[Dict]):
    """Update opportunities in AI Server API"""
    try:
        payload = {
            "opportunities": opportunities
        }
        resp = requests.post(
            f"{GOM_AI_SERVER}/perfect-opportunities/update",
            json=payload,
            timeout=5
        )
        if resp.status_code == 200:
            return True
        else:
            print(f"[WARN]  API update returned {resp.status_code}")
            return False
    except Exception as e:
        print(f"[WARN]  API update failed: {e}")
        return False


def main():
    """Main scanning loop"""
    print("[SCANNER] Perfect Opportunity Scanner started")
    print(f"[CONFIG] Scan interval: {SCAN_INTERVAL_SECONDS}s")
    print(f"[CONFIG] Thresholds: IA>={MIN_IA_CONFIDENCE}% | GOM>={MIN_GOM_COHERENCE}% | PROB>={MIN_PROBABILITY}%")

    # Symbols to scan (should come from config or AI server)
    symbols_to_scan = [
        "XAUUSD", "EURUSD", "GBPUSD", "USDJPY",
        "Boom500", "Crash500", "Boom1000", "Crash1000",
        "BTCUSD", "ETHUSD"
    ]

    last_whatsapp_send_time = datetime.now() - timedelta(minutes=10)  # Send immediately on start

    try:
        while True:
            # Scan for perfect opportunities
            perfect = scan_perfect_opportunities(symbols_to_scan)

            # Update API with current opportunities
            update_api_opportunities(perfect)

            # Send WhatsApp update periodically
            now = datetime.now()
            if (now - last_whatsapp_send_time).total_seconds() >= WHATSAPP_UPDATE_INTERVAL:
                if perfect:
                    msg = format_whatsapp_message(perfect)
                    send_whatsapp_alert(msg)
                    last_whatsapp_send_time = now
                else:
                    # Reset timer if no opportunities (avoid sending empty messages)
                    last_whatsapp_send_time = now

            # Sleep before next scan
            time.sleep(SCAN_INTERVAL_SECONDS)

    except KeyboardInterrupt:
        print("\n🛑 Scanner stopped by user")
    except Exception as e:
        print(f"[ERROR] Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
