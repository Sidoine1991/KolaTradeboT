#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test Audio Transcription with OpenAI Whisper
Tests the received WhatsApp audio file
"""

import sys
import io
import os
from pathlib import Path

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

print("=" * 70)
print("  AUDIO TRANSCRIPTION TEST - OpenAI Whisper")
print("=" * 70)

# Check if openai package is installed
try:
    from openai import OpenAI
    print("✅ OpenAI package installed")
except ImportError:
    print("❌ OpenAI package not installed")
    print("   Install with: pip install openai")
    sys.exit(1)

# Check for API key in environment
api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    print("\n❌ OPENAI_API_KEY not found in environment")
    print("   This is likely why PsychoBot transcription failed!")
    print("\n   To fix:")
    print("   1. Get API key from: https://platform.openai.com/api-keys")
    print("   2. Set in Render dashboard for PsychoBot service")
    print("   3. Or test locally: export OPENAI_API_KEY=sk-proj-xxx...\n")

    # Ask if user wants to provide key for local test
    print("\n💡 Do you want to test transcription locally with a temporary key?")
    print("   (Key will only be used for this test, not saved)")
    response = input("\n   Enter API key (or press Enter to skip): ").strip()

    if response:
        api_key = response
        print("\n✅ Using provided key for local test")
    else:
        print("\n⏭️  Skipping transcription test")
        sys.exit(0)
else:
    print(f"✅ OPENAI_API_KEY found (length: {len(api_key)} chars)")

# Audio file path
audio_file = Path("C:/Users/USER/Downloads/WhatsApp Ptt 2026-05-31 at 11.04.33.ogg")

if not audio_file.exists():
    print(f"\n❌ Audio file not found: {audio_file}")
    sys.exit(1)

print(f"✅ Audio file found: {audio_file.name}")
print(f"   Size: {audio_file.stat().st_size / 1024:.1f} KB")

# Try transcription
print("\n" + "=" * 70)
print("  TRANSCRIPTION TEST")
print("=" * 70)

try:
    client = OpenAI(api_key=api_key)

    print("\n🎙️  Transcribing audio...")
    print("   This may take 5-10 seconds...\n")

    with open(audio_file, "rb") as audio:
        transcript = client.audio.transcriptions.create(
            model="whisper-1",
            file=audio,
            language="fr"  # French
        )

    print("✅ TRANSCRIPTION SUCCESSFUL!\n")
    print("=" * 70)
    print("📝 TRANSCRIPT:")
    print("=" * 70)
    print(f"\n{transcript.text}\n")
    print("=" * 70)

    # Analysis
    word_count = len(transcript.text.split())
    duration_estimate = audio_file.stat().st_size / 1024 / 15  # Rough estimate

    print(f"\n📊 ANALYSIS:")
    print(f"   Words: {word_count}")
    print(f"   Estimated duration: ~{duration_estimate:.1f} seconds")
    print(f"   Language: French (specified)")

    print("\n" + "=" * 70)
    print("  DIAGNOSIS")
    print("=" * 70)
    print("""
✅ Transcription works with valid API key
❌ PsychoBot failed because OPENAI_API_KEY is missing/invalid

ACTION REQUIRED:
1. Go to: https://dashboard.render.com
2. Select: psychobot-1si7 service
3. Go to: Environment tab
4. Add/Update: OPENAI_API_KEY=sk-proj-xxx...
5. Click: Save Changes
6. Render will auto-redeploy with new key

After fixing, test by sending another voice message to:
+229 01 96 91 13 46
    """)

    sys.exit(0)

except Exception as e:
    print(f"\n❌ TRANSCRIPTION FAILED!")
    print(f"   Error: {str(e)}\n")

    error_msg = str(e).lower()

    if "api key" in error_msg or "authentication" in error_msg or "401" in error_msg:
        print("🔑 ISSUE: Invalid or missing API key")
        print("   The API key is incorrect or has expired")
        print("\n   Solution:")
        print("   1. Generate new key: https://platform.openai.com/api-keys")
        print("   2. Update in Render dashboard")
    elif "quota" in error_msg or "billing" in error_msg:
        print("💳 ISSUE: API quota exceeded or billing problem")
        print("   Your OpenAI account may need credits")
        print("\n   Solution:")
        print("   1. Check: https://platform.openai.com/account/billing")
        print("   2. Add credits or upgrade plan")
    elif "rate" in error_msg or "429" in error_msg:
        print("⏱️  ISSUE: Rate limit exceeded")
        print("   Too many requests in short time")
        print("\n   Solution:")
        print("   Wait 1 minute and try again")
    else:
        print("🔧 ISSUE: Technical error")
        print("   Check error message above for details")

    print("\n" + "=" * 70)
    sys.exit(1)

if __name__ == "__main__":
    pass
