"""
Career-Ops PsychoBot Bridge
Intégration bidirectionnelle: Career-Ops ↔ PsychoBot WhatsApp
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional
import os
import json
import logging
from datetime import datetime

from psychobot_commands_careerops import CareerOpsCommandHandler

logger = logging.getLogger("career_ops_bridge")

router = APIRouter(prefix="/career-ops", tags=["Career-Ops"])

PSYCHOBOT_URL = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
WHATSAPP_PHONE = os.getenv("WHATSAPP_PHONE", "+2290196911346")


class IncomingWhatsAppMessage(BaseModel):
    """Message entrant depuis PsychoBot"""
    phone: str
    message: str
    timestamp: Optional[str] = None
    message_id: Optional[str] = None


class SendWhatsAppMessage(BaseModel):
    """Message à envoyer via PsychoBot"""
    phone: str
    message: str


@router.post("/webhook/incoming-message")
async def handle_incoming_message(msg: IncomingWhatsAppMessage, background_tasks: BackgroundTasks):
    """
    Webhook pour recevoir les messages WhatsApp entrants depuis PsychoBot
    Traite les commandes Career-Ops
    """
    try:
        logger.info(f"[Career-Ops] Incoming message from {msg.phone}: {msg.message[:50]}")

        # Process the message with CareerOps
        handler = CareerOpsCommandHandler()
        response = await handler.process_message(msg.message)

        # Send response back via PsychoBot
        background_tasks.add_task(
            send_whatsapp_response,
            phone=msg.phone,
            message=response
        )

        return {
            "ok": True,
            "phone": msg.phone,
            "command_detected": True,
            "response_queued": True
        }

    except Exception as e:
        logger.error(f"[Career-Ops] Error: {str(e)}")
        return {
            "ok": False,
            "error": str(e)[:100]
        }


async def send_whatsapp_response(phone: str, message: str):
    """Send response back to user via PsychoBot"""
    try:
        import requests

        resp = requests.post(
            f"{PSYCHOBOT_URL}/send-message",
            json={"phone": phone, "message": message},
            timeout=30
        )

        if resp.status_code == 200:
            logger.info(f"[Career-Ops] Response sent to {phone}")
        else:
            logger.error(f"[Career-Ops] Failed to send: {resp.status_code}")

    except Exception as e:
        logger.error(f"[Career-Ops] Error sending response: {str(e)}")


@router.post("/send-message")
async def send_careerops_message(req: SendWhatsAppMessage):
    """Send Career-Ops message via PsychoBot"""
    try:
        import requests

        resp = requests.post(
            f"{PSYCHOBOT_URL}/send-message",
            json={"phone": req.phone, "message": req.message},
            timeout=30
        )

        ok = resp.status_code == 200
        logger.info(f"[Career-Ops] Message to {req.phone}: {'OK' if ok else 'FAIL'}")

        return {
            "ok": ok,
            "phone": req.phone,
            "status_code": resp.status_code
        }

    except Exception as e:
        logger.error(f"[Career-Ops] Error: {str(e)}")
        return {
            "ok": False,
            "error": str(e)[:100]
        }


@router.get("/help")
async def get_help():
    """Get help text with all commands"""
    handler = CareerOpsCommandHandler()
    return {
        "help": handler.get_help_text(),
        "commands": handler.get_commands_list_formatted()
    }


@router.get("/commands")
async def list_commands():
    """List all available commands"""
    handler = CareerOpsCommandHandler()
    commands_list = []

    for cmd, info in handler.commands.items():
        commands_list.append({
            "command": cmd,
            "description": info["description"],
            "synonyms": info.get("synonyms", [])
        })

    return {
        "commands": commands_list,
        "total": len(commands_list)
    }


@router.post("/test-command")
async def test_command(message: dict):
    """Test a command without sending via WhatsApp"""
    try:
        user_input = message.get("message", "")
        handler = CareerOpsCommandHandler()
        response = await handler.process_message(user_input)

        return {
            "ok": True,
            "input": user_input,
            "response": response
        }

    except Exception as e:
        return {
            "ok": False,
            "error": str(e)[:100]
        }


@router.get("/status")
async def get_status():
    """Get Career-Ops status"""
    handler = CareerOpsCommandHandler()
    status = {
        "service": "Career-Ops",
        "status": "operational" if handler.repo else "degraded",
        "database": "connected" if handler.repo else "not available",
        "profile": "loaded" if handler.profile else "not loaded",
        "commands": len(handler.commands),
        "timestamp": datetime.utcnow().isoformat()
    }

    return status
