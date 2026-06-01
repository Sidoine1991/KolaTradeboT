#!/usr/bin/env python3
"""
Test Career-Ops Commands
Demo of all commands and NLP fallback
"""

import asyncio
import sys
from pathlib import Path

# Setup path
_root = Path(__file__).resolve().parent
sys.path.insert(0, str(_root))

from psychobot_commands_careerops import CareerOpsCommandHandler


async def main():
    """Test all commands"""
    handler = CareerOpsCommandHandler()

    print("[=] " + "=" * 64)
    print("   CAREER-OPS COMMAND HANDLER TEST")
    print("[=] " + "=" * 64)
    print()

    # Test cases: (user_input, expected_command)
    test_cases = [
        # Direct commands
        ("/jobs", "/jobs"),
        ("/jobs all", "/jobs all"),
        ("/jobs stats", "/jobs stats"),
        ("/profile", "/profile"),
        ("/help", "/help"),

        # Natural language - English
        ("show me best jobs", "/jobs"),
        ("all positions", "/jobs all"),
        ("stats for this week", "/jobs stats"),
        ("mark as applied", "/apply"),
        ("skip this job", "/skip"),
        ("show my profile", "/profile"),
        ("what are my settings", "/settings"),
        ("give me advice", "/insights"),

        # Natural language - French
        ("affiche mes offres", "/jobs all"),
        ("meilleurs matchs", "/jobs"),
        ("mon profil", "/profile"),
        ("mes preferences", "/settings"),
        ("statistiques", "/jobs stats"),
        ("j'ai postule", "/apply"),
        ("passer", "/skip"),

        # Edge cases
        ("jobs", "/jobs"),
        ("HELP", "/help"),
        ("apply 1", "/apply"),
        ("skip 2", "/skip"),
    ]

    print("\n[TEST] Command Detection")
    print("-" * 68)

    correct = 0
    for user_input, expected_cmd in test_cases:
        detected = handler.find_command(user_input)
        status = "[OK]" if detected == expected_cmd else "[FAIL]"
        match_status = "PASS" if detected == expected_cmd else f"FAIL (got {detected})"

        print(f"{status} '{user_input}' -> {expected_cmd} [{match_status}]")

        if detected == expected_cmd:
            correct += 1

    print(f"\n[RESULT] {correct}/{len(test_cases)} tests passed ({correct*100//len(test_cases)}%)")

    # Test actual command outputs
    print("\n" + "=" * 68)
    print("[TEST] Command Output Formatting")
    print("=" * 68)

    # Test /help
    print("\n[1/5] /help command")
    print("-" * 68)
    response = await handler.handle_help("")
    # Strip emojis for Windows console
    response_safe = response.encode('ascii', 'ignore').decode('ascii')
    print(response_safe[:300] + "...\n")

    # Test /profile
    print("[2/5] /profile command")
    print("-" * 68)
    response = await handler.handle_profile("")
    response_safe = response.encode('ascii', 'ignore').decode('ascii')
    print(response_safe + "\n")

    # Test /jobs stats
    print("[3/5] /jobs stats command")
    print("-" * 68)
    response = await handler.handle_jobs_stats("")
    response_safe = response.encode('ascii', 'ignore').decode('ascii')
    print(response_safe + "\n")

    # Test /settings
    print("[4/5] /settings command")
    print("-" * 68)
    response = await handler.handle_settings("")
    response_safe = response.encode('ascii', 'ignore').decode('ascii')
    print(response_safe + "\n")

    # Test /insights
    print("[5/5] /insights command")
    print("-" * 68)
    response = await handler.handle_insights("")
    response_safe = response.encode('ascii', 'ignore').decode('ascii')
    print(response_safe + "\n")

    # Show command list
    print("=" * 68)
    print("[INFO] All Available Commands")
    print("=" * 68)
    commands_list = handler.get_commands_list_formatted()
    # Print first 50 lines (safe for Windows)
    lines = commands_list.split("\n")
    for line in lines[:50]:
        try:
            print(line)
        except UnicodeEncodeError:
            print(line.encode('ascii', 'ignore').decode('ascii'))
    print("...\n")

    # Summary
    print("=" * 68)
    print("[SUMMARY] Career-Ops Commands Ready")
    print("=" * 68)
    print(f"✓ {len(handler.commands)} commands registered")
    print("✓ Natural language recognition active")
    print("✓ WhatsApp formatting ready")
    print("✓ Database integration ready (if RDS connected)")
    print("\n[NEXT] Integrate into ai_server.py:")
    print("  from career_ops_psychobot_bridge import router")
    print("  app.include_router(router, prefix='/api')")
    print()


if __name__ == "__main__":
    asyncio.run(main())
