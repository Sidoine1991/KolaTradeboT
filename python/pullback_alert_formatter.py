#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pullback Alert Formatter — Format beautifully styled WhatsApp messages for Pullback Entry System
Integrates with existing TradBOT notification architecture
Uses the same send_whatsapp_report pattern as gom_sync_with_report.py
"""

import sys
import io
from datetime import datetime
from typing import Dict, Optional

# UTF-8 wrapper for Windows console
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

class PullbackAlertFormatter:
    """
    Formats beautiful WhatsApp messages for pullback entry phases
    CALIBRATED to match existing GOM notification style and emoji patterns
    """

    # Emoji mapping — aligned with GOM report style
    EMOJI = {
        'pullback': '🎯',          # Same as GOM "GOM VERDICTS"
        'detected': '📉',          # Visual indicator (price down)
        'signal': '✅',            # Go signal (matches GOM OTE checkmark)
        'trade': '💰',             # Trade execution
        'buy': '🟢',               # PERFECT/GOOD BUY (matches GOM emoji_map[3]=🟢)
        'sell': '🔴',              # PERFECT/GOOD SELL (matches GOM emoji_map[-3]=🔴)
        'wait': '⚪',              # WAIT state (matches GOM emoji_map[0]=⚪)
        'info': 'ℹ️',              # Informational
        'warning': '⚠️',           # Warning/caution
        'time': '⏰',              # Timestamp (matches GOM time marker)
        'chart': '📊',             # Chart/data (matches GOM report header)
        'ml': '🤖',                # ML indicator (matches GOM ML row)
        'coherence': '🔗',         # Link/coherence
        'arrow_up': '↗️',          # Price up/target
        'arrow_down': '↘️',        # Price down/stop loss
        'separator': '═',          # Line separator (matches GOM report)
    }

    @staticmethod
    def format_pullback_started(
        symbol: str,
        direction: str,
        breakout_price: float,
        pullback_min: float,
        pullback_max: float,
        gom_level: Optional[str] = None,
        gom_confidence: Optional[float] = None,
        coherence_pct: Optional[float] = None,
        timestamp: Optional[str] = None
    ) -> str:
        """
        Format PHASE 1: Pullback tracking started
        CALIBRATED with GOM context (level, confidence, coherence)
        """

        if timestamp is None:
            timestamp = datetime.now().strftime("%H:%M:%S UTC")

        direction_emoji = PullbackAlertFormatter.EMOJI['buy'] if direction.upper() == 'BUY' else PullbackAlertFormatter.EMOJI['sell']

        message = f"""{PullbackAlertFormatter.EMOJI['pullback']} *PULLBACK ENTRY INITIATED*

{direction_emoji} *{symbol}* — {direction.upper()}
Entry Level: {breakout_price:.2f}

{PullbackAlertFormatter.EMOJI['chart']} *GOM Context:*"""

        if gom_level:
            message += f"\nGOM Level: {gom_level}"
        if gom_confidence:
            message += f"\nConfidence: {gom_confidence*100:.0f}%"
        if coherence_pct:
            message += f"\nCoherence: {coherence_pct:.0f}%"

        message += f"""

*Attente Pullback:*
Recul visé: {pullback_min:.1f}% - {pullback_max:.1f}%

{PullbackAlertFormatter.EMOJI['time']} {timestamp}"""

        return message

    @staticmethod
    def format_pullback_detected(
        symbol: str,
        direction: str,
        pullback_pct: float,
        pullback_price: float,
        breakout_price: float,
        atr: Optional[float] = None,
        ml_confidence: Optional[float] = None,
        timestamp: Optional[str] = None
    ) -> str:
        """
        Format PHASE 2: Pullback confirmed
        CALIBRATED with technical context (ATR, ML score)
        """

        if timestamp is None:
            timestamp = datetime.now().strftime("%H:%M:%S UTC")

        direction_emoji = PullbackAlertFormatter.EMOJI['buy'] if direction.upper() == 'BUY' else PullbackAlertFormatter.EMOJI['sell']
        movement = f"{PullbackAlertFormatter.EMOJI['arrow_down']}" if direction.upper() == 'BUY' else f"{PullbackAlertFormatter.EMOJI['arrow_up']}"

        message = f"""{PullbackAlertFormatter.EMOJI['detected']} *PULLBACK DETECTED*

{direction_emoji} *{symbol}* — {direction.upper()}

*Pullback Stats:*
{movement} {pullback_pct:.2f}% | Low: {pullback_price:.2f}"""

        if atr:
            message += f"\nATR: {atr:.2f}"

        message += f"""

*GOM Reference:*
Breakout: {breakout_price:.2f}"""

        if ml_confidence:
            ml_icon = PullbackAlertFormatter.EMOJI['buy'] if direction.upper() == 'BUY' else PullbackAlertFormatter.EMOJI['sell']
            message += f"\n{PullbackAlertFormatter.EMOJI['ml']} ML: {ml_icon} {ml_confidence*100:.0f}%"

        message += f"""

{PullbackAlertFormatter.EMOJI['chart']} *Awaiting resumption signal...*

{PullbackAlertFormatter.EMOJI['time']} {timestamp}"""

        return message

    @staticmethod
    def format_resumption_confirmed(
        symbol: str,
        direction: str,
        entry_price: float,
        sl: float,
        tp: float,
        lot: float,
        signals_detail: str = "EMA Cross + Volume Spike",
        gom_coherence: Optional[float] = None,
        gom_level_name: Optional[str] = None,
        timestamp: Optional[str] = None
    ) -> str:
        """
        Format PHASE 3: Resumption signal GO!
        CALIBRATED with GOM coherence and entry level context
        """

        if timestamp is None:
            timestamp = datetime.now().strftime("%H:%M:%S UTC")

        direction_emoji = PullbackAlertFormatter.EMOJI['buy'] if direction.upper() == 'BUY' else PullbackAlertFormatter.EMOJI['sell']
        rr_ratio = abs((tp - entry_price) / (entry_price - sl)) if (entry_price - sl) != 0 else 0

        message = f"""{PullbackAlertFormatter.EMOJI['signal']} *RESUMPTION CONFIRMED — GO!*

{direction_emoji} *{symbol}* — {direction.upper()}

*ENTRY:* {entry_price:.2f}"""

        if gom_level_name:
            message += f" ({gom_level_name})"

        message += f"""
*SL:* {sl:.2f} {PullbackAlertFormatter.EMOJI['arrow_down']}
*TP:* {tp:.2f} {PullbackAlertFormatter.EMOJI['arrow_up']}
*Lot:* {lot:.2f}

*Risk/Reward:* 1:{rr_ratio:.2f}"""

        if gom_coherence:
            coherence_icon = PullbackAlertFormatter.EMOJI['buy'] if gom_coherence >= 70 else PullbackAlertFormatter.EMOJI['warning']
            message += f"\n{PullbackAlertFormatter.EMOJI['coherence']} Coherence: {coherence_icon} {gom_coherence:.0f}%"

        message += f"""

*Signals:* {signals_detail}

{PullbackAlertFormatter.EMOJI['time']} {timestamp}"""

        return message

    @staticmethod
    def format_trade_opened(
        symbol: str,
        direction: str,
        entry_price: float,
        sl: float,
        tp: float,
        lot: float,
        ticket: int,
        risk_usd: float,
        reward_usd: float,
        gom_verdict: Optional[str] = None,
        gom_confidence: Optional[float] = None,
        entry_method: str = "PULLBACK",
        timestamp: Optional[str] = None
    ) -> str:
        """
        Format PHASE 4: Trade opened successfully
        CALIBRATED with GOM verdict context and entry method
        """

        if timestamp is None:
            timestamp = datetime.now().strftime("%H:%M:%S UTC")

        direction_emoji = PullbackAlertFormatter.EMOJI['buy'] if direction.upper() == 'BUY' else PullbackAlertFormatter.EMOJI['sell']
        rr = reward_usd / risk_usd if risk_usd > 0 else 0

        message = f"""{PullbackAlertFormatter.EMOJI['trade']} *TRADE OPENED*

{direction_emoji} *{symbol}* | Method: {entry_method}
Ticket: #{ticket}

*ENTRY:* {entry_price:.2f}
*SL:* {sl:.2f}
*TP:* {tp:.2f}
*Lot:* {lot:.2f}

*Risk/Reward:*
Risk: ${risk_usd:.2f} | Reward: ${reward_usd:.2f}
Ratio: 1:{rr:.2f}"""

        if gom_verdict:
            message += f"\n\n{PullbackAlertFormatter.EMOJI['chart']} GOM Context:"
            message += f"\nVerdict: {gom_verdict}"

        if gom_confidence:
            message += f"\nConfidence: {gom_confidence*100:.0f}%"

        message += f"""

{PullbackAlertFormatter.EMOJI['time']} {timestamp}"""

        return message

    @staticmethod
    def format_trade_failed(
        symbol: str,
        direction: str,
        error_code: str,
        reason: str,
        timestamp: Optional[str] = None
    ) -> str:
        """Format ERROR: Trade opening failed"""

        if timestamp is None:
            timestamp = datetime.now().strftime("%H:%M:%S UTC")

        direction_emoji = PullbackAlertFormatter.EMOJI['buy'] if direction.upper() == 'BUY' else PullbackAlertFormatter.EMOJI['sell']

        message = f"""{PullbackAlertFormatter.EMOJI['warning']} *TRADE ÉCHOUÉ*

*Symbole:* {symbol}
*Direction:* {direction_emoji} {direction.upper()}

*Erreur:* {error_code}
*Raison:* {reason}

Veuillez vérifier les logs.

{PullbackAlertFormatter.EMOJI['time']} {timestamp}"""

        return message


# ════════════════════════════════════════════════════════════════
# Integration helper for existing TradBOT notification architecture
# ════════════════════════════════════════════════════════════════

def send_pullback_alert(
    message: str,
    send_function,
    source: str = "tradbot-pullback"
) -> bool:
    """
    Send formatted pullback alert using existing TradBOT send_whatsapp function

    Args:
        message: Formatted message (from PullbackAlertFormatter)
        send_function: Reference to existing send_whatsapp_report function
        source: Alert source identifier

    Returns:
        True if sent successfully, False otherwise
    """
    try:
        return send_function(message)
    except Exception as e:
        print(f"[ERROR] Failed to send pullback alert: {e}")
        return False


# Test/example usage
if __name__ == "__main__":

    formatter = PullbackAlertFormatter()

    print("\n" + "="*80)
    print("PHASE 1: PULLBACK STARTED")
    print("="*80)
    msg1 = formatter.format_pullback_started(
        symbol="Boom 150 Index",
        direction="BUY",
        breakout_price=1456.23,
        pullback_min=0.5,
        pullback_max=1.5
    )
    print(msg1)

    print("\n" + "="*80)
    print("PHASE 2: PULLBACK DETECTED")
    print("="*80)
    msg2 = formatter.format_pullback_detected(
        symbol="Boom 150 Index",
        direction="BUY",
        pullback_pct=0.92,
        pullback_price=1452.11,
        breakout_price=1456.23
    )
    print(msg2)

    print("\n" + "="*80)
    print("PHASE 3: RESUMPTION CONFIRMED (SIGNAL GO)")
    print("="*80)
    msg3 = formatter.format_resumption_confirmed(
        symbol="Boom 150 Index",
        direction="BUY",
        entry_price=1453.45,
        sl=1451.95,
        tp=1455.20,
        lot=0.01,
        signals_detail="EMA Cross + Volume Spike (2/3)"
    )
    print(msg3)

    print("\n" + "="*80)
    print("PHASE 4: TRADE OPENED")
    print("="*80)
    msg4 = formatter.format_trade_opened(
        symbol="Boom 150 Index",
        direction="BUY",
        entry_price=1453.45,
        sl=1451.95,
        tp=1455.20,
        lot=0.01,
        ticket=12345,
        risk_usd=0.48,
        reward_usd=0.53
    )
    print(msg4)

    print("\n" + "="*80)
    print("ERROR: TRADE FAILED")
    print("="*80)
    msg5 = formatter.format_trade_failed(
        symbol="Boom 150 Index",
        direction="BUY",
        error_code="RETCODE_NOT_ENOUGH_MONEY",
        reason="Marge insuffisante pour ce lot"
    )
    print(msg5)
