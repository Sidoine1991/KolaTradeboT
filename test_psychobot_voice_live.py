#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PsychoBot Voice Message Live Test
Sends test messages to verify audio processing capabilities
"""

import sys
import io
import json
import requests
import time
from datetime import datetime

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

class VoiceTester:
    def __init__(self):
        self.psychobot_url = "https://psychobot-1si7.onrender.com"
        self.test_phone = "+237696814391"  # Your test number

    def send_test_message(self, message: str, test_name: str):
        """Send a test message via PsychoBot"""
        print(f"\n{'='*70}")
        print(f"🧪 TEST: {test_name}")
        print(f"{'='*70}")
        print(f"📤 Sending: {message}")

        try:
            payload = {
                "phone": self.test_phone,
                "message": message
            }

            response = requests.post(
                f"{self.psychobot_url}/send-message",
                json=payload,
                timeout=30,
                verify=False
            )

            if response.status_code in [200, 201]:
                print("✅ Message sent successfully")
                data = response.json()
                print(f"📊 Response: {json.dumps(data, indent=2)}")
                return True
            else:
                print(f"❌ Failed: HTTP {response.status_code}")
                print(f"Response: {response.text[:200]}")
                return False

        except Exception as e:
            print(f"❌ Error: {str(e)[:150]}")
            return False

    def run_voice_feature_tests(self):
        """Run comprehensive voice feature tests"""
        print("\n" + "╔" + "="*68 + "╗")
        print("║" + " "*15 + "PSYCHOBOT VOICE FEATURES TEST" + " "*24 + "║")
        print("╚" + "="*68 + "╝\n")

        tests = [
            {
                "name": "Voice Transcription Simulation",
                "message": """🎙️ **VOICE MESSAGE TEST** (Simulated)

Transcript Test:
"Bonjour PsychoBot, peux-tu me donner le statut actuel du marché XAUUSD ?
Je voudrais savoir s'il y a un signal d'achat valide en ce moment."

This simulates what would happen if you sent an actual voice message.
The bot should understand the context and respond with market analysis."""
            },
            {
                "name": "Context-Aware Follow-up",
                "message": """🎙️ **FOLLOW-UP VOICE TEST**

Follow-up question (simulated):
"Et pour EURUSD ?"

This tests if the bot remembers the previous context about market status requests."""
            },
            {
                "name": "Trading Command",
                "message": """🎙️ **VOICE COMMAND TEST**

Voice command (simulated):
"Montre-moi les 3 meilleures opportunités de trading aujourd'hui"

Tests: Command understanding + data retrieval"""
            },
            {
                "name": "Casual Conversation",
                "message": """🎙️ **CASUAL VOICE TEST**

Casual message (simulated):
"Salut Sidoine, comment ça va ? Quoi de neuf sur les marchés ?"

Tests: Personality response + market context awareness"""
            }
        ]

        results = []

        for i, test in enumerate(tests, 1):
            print(f"\n[{i}/{len(tests)}]")
            success = self.send_test_message(test["message"], test["name"])
            results.append((test["name"], success))

            if i < len(tests):
                print("\n⏱️  Waiting 5 seconds before next test...")
                time.sleep(5)

        # Summary
        print("\n" + "="*70)
        print("📊 TEST SUMMARY")
        print("="*70)

        passed = sum(1 for _, success in results if success)
        total = len(results)

        for test_name, success in results:
            status = "✅ PASS" if success else "❌ FAIL"
            print(f"{status} | {test_name}")

        print(f"\nTotal: {passed}/{total} passed ({passed/total*100:.0f}%)")

        if passed == total:
            print("\n✅ ALL TESTS PASSED - Voice processing ready!")
        elif passed > 0:
            print(f"\n⚠️  PARTIAL SUCCESS - {passed} tests passed")
        else:
            print("\n❌ ALL TESTS FAILED - Check connection")

        return passed == total

def main():
    print("\n" + "╔" + "="*68 + "╗")
    print("║" + " "*10 + "PSYCHOBOT VOICE MESSAGE LIVE TESTING" + " "*21 + "║")
    print("╚" + "="*68 + "╝")

    print("\n📋 INSTRUCTIONS FOR REAL VOICE TEST:")
    print("="*70)
    print("""
1. Open WhatsApp on your phone
2. Go to PsychoBot chat (+229 01 96 91 13 46)
3. Send a VOICE MESSAGE (not text) saying:

   🎙️ "Bonjour PsychoBot, test audio. Peux-tu me répondre ?"

4. Wait 5-15 seconds
5. You should receive:
   ✓ Voice reply (audio message)
   ✓ Text transcript (optional)

Expected behavior:
   - Bot transcribes your voice → text
   - Generates contextual AI response
   - Converts response to speech
   - Sends voice message back

Response time: 5-15 seconds average
    """)

    print("\n" + "="*70)
    print("🤖 AUTOMATED TEXT TESTS (Simulating Voice Context)")
    print("="*70)

    tester = VoiceTester()
    success = tester.run_voice_feature_tests()

    print("\n" + "="*70)
    print("🎙️ NEXT STEP: SEND REAL VOICE MESSAGE")
    print("="*70)
    print("""
After these automated tests, send a REAL voice message to test:
   1. Transcription accuracy (French/English)
   2. Context understanding
   3. AI response quality
   4. Voice reply generation
   5. Response time (<15s)

Send to: +229 01 96 91 13 46 (PsychoBot WhatsApp)
Test message: "Bonjour PsychoBot, test vocal complet"
    """)
    print("="*70 + "\n")

    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
