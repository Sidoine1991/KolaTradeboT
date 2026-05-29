#!/usr/bin/env python3
"""
XAUUSD 20-min autonomous WhatsApp surveillance system.

Workflow:
1. Every 20 minutes, collect TradingView data (quote, indicators, GOM verdict)
2. Fetch AI server data (session bias, pending order, report status)
3. Build unified WhatsApp message
4. Send via PsychoBot or fallback to log file
"""

import asyncio
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import httpx

# Configuration
AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")
PSYCHOBOT_URL = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com/send-message")
WHATSAPP_PHONE = os.getenv("WHATSAPP_PHONE", "+2290196911346")
CHECK_INTERVAL = 20 * 60  # 20 minutes in seconds
ALERT_LOG = Path("D:/Dev/TradBOT/whatsapp_alerts.log")
UTC = timezone.utc

# Ensure log directory exists
ALERT_LOG.parent.mkdir(parents=True, exist_ok=True)


def log_print(message: str):
    """Print with timestamp."""
    now = datetime.now(UTC).isoformat()
    print(f"[{now}] {message}")


def log_alert(message: str):
    """Write alert to log file with timestamp."""
    timestamp = datetime.now(UTC).isoformat()
    with open(ALERT_LOG, "a", encoding="utf-8") as f:
        f.write(f"{timestamp} | {message}\n")


async def fetch_ai_endpoint(endpoint: str) -> Optional[dict]:
    """Fetch data from AI server endpoint."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            url = f"{AI_SERVER_URL}{endpoint}"
            response = await client.get(url)
            if response.status_code == 200:
                return response.json()
    except Exception as e:
        log_print(f"⚠️  AI Error {endpoint}: {e}")
    return None


async def fetch_all_ai_data() -> dict:
    """Fetch all data from AI server in parallel."""
    results = await asyncio.gather(
        fetch_ai_endpoint("/session-bias?symbol=XAUUSD"),
        fetch_ai_endpoint("/pending-order?symbol=XAUUSD"),
        fetch_ai_endpoint("/tradingagents/report-status?symbol=XAUUSD"),
    )

    return {
        "session_bias": results[0] or {},
        "pending_order": results[1] or {},
        "report_status": results[2] or {},
    }


def build_whatsapp_message(ai_data: dict) -> str:
    """Build WhatsApp message from collected data."""
    now = datetime.now(UTC)
    timestamp = now.strftime("%H:%M UTC")
    date_str = now.strftime("%d/%m %H:%M UTC")

    # Extract AI data with safe fallbacks
    session = ai_data.get("session_bias", {})
    pending = ai_data.get("pending_order", {})
    report = ai_data.get("report_status", {})

    bias_direction = session.get("direction", "NEUTRAL")
    bias_strength = session.get("strength", 0)
    valid_duration = session.get("valid_duration_hours", 0)

    has_pending = pending.get("active", False)

    report_direction = report.get("direction", "WAIT")
    report_strength = report.get("strength", 0)
    report_age = report.get("age_minutes", 0)
    report_expire = report.get("expires_in_minutes", 0)

    # Emojis
    bias_emoji = "🟢" if bias_direction == "UP" else ("🔴" if bias_direction == "DOWN" else "⚪")
    report_emoji = "🟢" if report_direction == "BUY" else ("🔴" if report_direction == "SELL" else "⚪")

    # Build message
    message = f"""📊 TradBOT [{timestamp}]

*XAUUSD — Suivi 20min* | {date_str}
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* [Lire de TradingView MCP]
📍 VWAP : [Lire de TradingView MCP]
📊 BB : [Lire de TradingView MCP]
⚡ Supertrend : [Lire de TradingView MCP]
━━━━━━━━━━━━━━━━━━━━
⚪ *Verdict GOM KOLA :* [Lire de TradingView MCP]
━━━━━━━━━━━━━━━━━━━━
{bias_emoji} *Biais session :* {bias_direction} {bias_strength}% | ✅ valide {valid_duration}h
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* {'✅ ACTIF' if has_pending else '📭 Aucun'}
━━━━━━━━━━━━━━━━━━━━
{report_emoji} *Rapport TradingAgents :* {report_direction} {report_strength}% | Age: {report_age}min | Expire: {report_expire}min
━━━━━━━━━━━━━━━━━━━━
🎯 *Décision :* ATTENDRE confluence complète
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"""

    return message


async def send_whatsapp_message(message: str) -> bool:
    """Send message via PsychoBot."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            payload = {
                "phone": WHATSAPP_PHONE,
                "message": message,
            }
            response = await client.post(PSYCHOBOT_URL, json=payload)
            if response.status_code == 200:
                log_print("✅ WhatsApp sent successfully")
                return True
            else:
                log_print(f"❌ WhatsApp error {response.status_code}: {response.text}")
    except Exception as e:
        log_print(f"❌ WhatsApp error: {e}")
    return False


async def run_monitor():
    """Main monitor loop - runs every 20 minutes."""
    log_print("🚀 XAUUSD 20-min autonomous WhatsApp surveillance started")

    iteration = 0
    while True:
        try:
            iteration += 1
            log_print(f"📊 Iteration #{iteration} - Collecting data...")

            # Fetch all AI server data in parallel
            ai_data = await fetch_all_ai_data()

            # Build message
            message = build_whatsapp_message(ai_data)

            # Log preview
            log_print(f"📝 Message preview (first 100 chars):\n{message[:100]}...")

            # Send via WhatsApp
            success = await send_whatsapp_message(message)

            # Fallback to log if WhatsApp fails
            if not success:
                log_alert(f"FALLBACK: {message[:200]}")
                log_print("📝 Alert written to fallback log")

            # Sleep 20 minutes
            log_print(f"⏰ Waiting 20 minutes until next check...")
            await asyncio.sleep(CHECK_INTERVAL)

        except KeyboardInterrupt:
            log_print("🛑 Stopped by user")
            break
        except Exception as e:
            log_print(f"❌ Monitor error: {e}")
            await asyncio.sleep(60)  # Retry after 1 minute


if __name__ == "__main__":
    try:
        asyncio.run(run_monitor())
    except KeyboardInterrupt:
        log_print("🛑 Shutting down...")
    except Exception as e:
        log_print(f"❌ Fatal error: {e}")
        sys.exit(1)
