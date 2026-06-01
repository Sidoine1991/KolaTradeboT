"""
PsychoBot Client
Send Career-Ops digest via WhatsApp through PsychoBot
"""

import os
import httpx
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent.parent / ".env")

PSYCHOBOT_URL = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
WHATSAPP_PHONE = os.getenv("WHATSAPP_PHONE", "+2290196911346")


class PsychoBotClient:
    """Send messages via PsychoBot WhatsApp integration"""

    def __init__(self, base_url: str = PSYCHOBOT_URL, phone: str = WHATSAPP_PHONE):
        self.base_url = base_url.rstrip("/")
        self.phone = phone
        self.timeout = 30

    async def send_message(self, message: str) -> bool:
        """Send message via PsychoBot"""

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"{self.base_url}/send-message",
                    json={
                        "phone": self.phone,
                        "message": message,
                    },
                )

                if response.status_code == 200:
                    print(f"[OK] Message sent via PsychoBot")
                    return True
                else:
                    print(f"[ERROR] PsychoBot returned {response.status_code}")
                    print(f"       Response: {response.text[:100]}")
                    return False

        except Exception as e:
            print(f"[ERROR] PsychoBot send failed: {str(e)[:100]}")
            return False

    async def send_digest(self, digest_message: str) -> bool:
        """Send digest message"""
        print(f"[INFO] Sending digest to {self.phone}...")
        return await self.send_message(digest_message)

    async def send_notification(self, title: str, body: str) -> bool:
        """Send notification"""
        message = f"*{title}*\n{body}"
        return await self.send_message(message)


async def send_career_ops_digest(message: str, phone: str = WHATSAPP_PHONE) -> bool:
    """Convenience function to send digest"""
    client = PsychoBotClient(phone=phone)
    return await client.send_digest(message)


if __name__ == "__main__":
    import asyncio

    async def test():
        client = PsychoBotClient()
        message = """*Test Career-Ops Digest*

✨ *EXCELLENT MATCH*
Senior Python Developer @ TechCorp
Score: 78%
$50k - $70k

👍 *GOOD MATCH*
Data Analyst @ StartupXYZ
Score: 65%

Reply /jobs for all matches!"""

        success = await client.send_digest(message)
        if success:
            print("[OK] Test digest sent!")
        else:
            print("[ERROR] Could not send test digest")

    asyncio.run(test())
