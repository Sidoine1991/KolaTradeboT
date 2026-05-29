#!/usr/bin/env python3
"""
XAUUSD 20-min WhatsApp surveillance system.
Collects TradingView + AI server data in parallel, sends unified WhatsApp alerts via PsychoBot.
"""

import asyncio
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

import httpx
import pytz

# Config
AI_SERVER_URL = "http://127.0.0.1:8000"
PSYCHOBOT_URL = "https://psychobot-1si7.onrender.com/send-message"
WHATSAPP_PHONE = os.getenv("WHATSAPP_PHONE", "+2290196911346")
ALERT_LOG = Path("D:/Dev/TradBOT/whatsapp_alerts.log")

# Timezone
UTC = pytz.UTC


def log_alert(message: str):
    """Write alert to log file with timestamp."""
    with open(ALERT_LOG, "a", encoding="utf-8") as f:
        f.write(f"{datetime.now(UTC).isoformat()} | {message}\n")


async def fetch_tradingview_quote() -> Optional[dict]:
    """Fetch XAUUSD live quote from TradingView MCP."""
    try:
        # Call the MCP function
        from mcp import ClientSession
        # This will be called via the TradingView MCP handler
        # For now, return a placeholder that will be filled by the MCP call
        print("[TradingView] Fetching XAUUSD quote...")
        return None  # Will be replaced by actual MCP data
    except Exception as e:
        print(f"[TradingView Quote Error] {e}")
        return None


async def fetch_tradingview_indicators() -> Optional[dict]:
    """Fetch study values (RSI, Supertrend, etc) from TradingView."""
    try:
        print("[TradingView] Fetching indicator values...")
        return None  # Will be replaced by actual MCP data
    except Exception as e:
        print(f"[TradingView Indicators Error] {e}")
        return None


async def fetch_gom_verdict() -> Optional[dict]:
    """Fetch GOM KOLA verdict from TradingView tables."""
    try:
        print("[TradingView] Fetching GOM KOLA verdict...")
        return None  # Will be replaced by actual MCP data
    except Exception as e:
        print(f"[TradingView GOM Error] {e}")
        return None


async def fetch_ai_session_bias() -> Optional[dict]:
    """Fetch session bias from AI server."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{AI_SERVER_URL}/session-bias?symbol=XAUUSD")
            if resp.status_code == 200:
                return resp.json()
    except Exception as e:
        print(f"[AI Session Bias Error] {e}")
    return None


async def fetch_ai_pending_order() -> Optional[dict]:
    """Fetch pending order from AI server."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{AI_SERVER_URL}/pending-order?symbol=XAUUSD")
            if resp.status_code == 200:
                return resp.json()
    except Exception as e:
        print(f"[AI Pending Order Error] {e}")
    return None


async def fetch_ai_report_status() -> Optional[dict]:
    """Fetch TradingAgents report status from AI server."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{AI_SERVER_URL}/tradingagents/report-status?symbol=XAUUSD")
            if resp.status_code == 200:
                return resp.json()
    except Exception as e:
        print(f"[AI Report Status Error] {e}")
    return None


async def collect_all_data() -> dict:
    """Collect all data from TradingView and AI server in parallel."""
    print("[Monitor] Starting data collection...")

    # Run all fetches in parallel
    results = await asyncio.gather(
        fetch_tradingview_quote(),
        fetch_tradingview_indicators(),
        fetch_gom_verdict(),
        fetch_ai_session_bias(),
        fetch_ai_pending_order(),
        fetch_ai_report_status(),
    )

    return {
        "quote": results[0],
        "indicators": results[1],
        "gom_verdict": results[2],
        "session_bias": results[3],
        "pending_order": results[4],
        "report_status": results[5],
    }


def format_whatsapp_message(data: dict) -> str:
    """Build WhatsApp message from collected data."""
    now = datetime.now(UTC)
    timestamp = now.strftime("%H:%M UTC")
    date_str = now.strftime("%d/%m %H:%M UTC")

    # Extract data or use placeholders if unavailable
    quote = data.get("quote") or {}
    price = quote.get("price", "N/A")

    indicators = data.get("indicators") or {}
    vwap = indicators.get("VWAP", "N/A")
    bb_lower = indicators.get("BB_lower", "N/A")
    bb_mid = indicators.get("BB_mid", "N/A")
    bb_upper = indicators.get("BB_upper", "N/A")
    supertrend = indicators.get("Supertrend", "N/A")
    rsi = indicators.get("RSI", "N/A")

    gom = data.get("gom_verdict") or {}
    gom_verdict = gom.get("verdict", "WAIT")
    gom_score_buy = gom.get("score_buy", 0)
    gom_score_sell = gom.get("score_sell", 0)
    spike_pct = gom.get("spike_pct", 0)

    session = data.get("session_bias") or {}
    bias_direction = session.get("direction", "NEUTRAL")
    bias_strength = session.get("strength", 0)
    valid_duration = session.get("valid_duration_hours", 0)

    pending = data.get("pending_order") or {}
    has_pending_order = pending.get("active", False)

    report = data.get("report_status") or {}
    report_direction = report.get("direction", "WAIT")
    report_strength = report.get("strength", 0)
    report_age_min = report.get("age_minutes", 0)
    report_expire_min = report.get("expires_in_minutes", 0)

    # Determine emoji based on verdict
    gom_emoji = "🟢" if gom_verdict == "BUY" else ("🔴" if gom_verdict == "SELL" else "⚪")
    bias_emoji = "🟢" if bias_direction == "UP" else ("🔴" if bias_direction == "DOWN" else "⚪")
    report_emoji = "🟢" if report_direction == "BUY" else ("🔴" if report_direction == "SELL" else "⚪")

    # Build message
    msg = f"""📊 TradBOT [{timestamp}]

*XAUUSD — Suivi 20min* | {date_str}
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* ${price}
📍 VWAP : ${vwap}
📊 BB : [{bb_lower} / {bb_mid} / {bb_upper}]
⚡ Supertrend : ${supertrend}
━━━━━━━━━━━━━━━━━━━━
{gom_emoji} *Verdict GOM KOLA : {gom_verdict}*
   BUY={gom_score_buy}  SELL={gom_score_sell}  Spike={spike_pct}%
   RSI={rsi}
━━━━━━━━━━━━━━━━━━━━
{bias_emoji} *Biais session :* {bias_direction} {bias_strength}% | ✅ valide {valid_duration}h
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* {'✅ ACTIF' if has_pending_order else '📭 Aucun'}
━━━━━━━━━━━━━━━━━━━━
{report_emoji} *Rapport TradingAgents :* {report_direction} {report_strength}% | Age: {report_age_min}min | Expire: {report_expire_min}min
━━━━━━━━━━━━━━━━━━━━
🎯 *Décision :* {gom_verdict} (confluence analysée)
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_
"""
    return msg


async def send_whatsapp_message(message: str) -> bool:
    """Send message via PsychoBot."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            payload = {
                "phone": WHATSAPP_PHONE,
                "message": message,
            }
            resp = await client.post(PSYCHOBOT_URL, json=payload)
            if resp.status_code == 200:
                print("[WhatsApp] Message sent successfully")
                return True
            else:
                print(f"[WhatsApp Error] Status {resp.status_code}: {resp.text}")
    except Exception as e:
        print(f"[WhatsApp Error] {e}")
    return False


async def send_fallback_alert(message: str):
    """Write alert to log file if WhatsApp fails."""
    log_alert(f"FALLBACK_LOG: {message}")
    print("[WhatsApp Fallback] Alert written to log file")


async def run_monitor():
    """Main monitor loop."""
    print("[Monitor] XAUUSD 20-min surveillance started")

    while True:
        try:
            # Collect all data in parallel
            data = await collect_all_data()

            # Format message
            message = format_whatsapp_message(data)
            print("\n" + "=" * 50)
            print(message)
            print("=" * 50 + "\n")

            # Send via WhatsApp
            success = await send_whatsapp_message(message)

            # Fallback to log if WhatsApp fails
            if not success:
                await send_fallback_alert(message)

            # Wait 20 minutes
            print("[Monitor] Waiting 20 minutes for next check...")
            await asyncio.sleep(20 * 60)

        except KeyboardInterrupt:
            print("[Monitor] Stopped by user")
            break
        except Exception as e:
            print(f"[Monitor Error] {e}")
            await asyncio.sleep(60)  # Retry after 1 min on error


if __name__ == "__main__":
    asyncio.run(run_monitor())
