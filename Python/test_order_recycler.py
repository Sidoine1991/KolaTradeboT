#!/usr/bin/env python3
"""Quick test of order recycler logic without API calls"""

from datetime import datetime, timezone, timedelta

# Simulate old pending order
now = datetime.now(timezone.utc)
order_created = now - timedelta(minutes=35)  # 35 minutes ago
age = (now - order_created).total_seconds() / 60.0

print("=" * 70)
print("ORDER RECYCLER — Logic Test")
print("=" * 70)
print()

print(f"Current time: {now.isoformat()}")
print(f"Order created: {order_created.isoformat()}")
print(f"Order age: {age:.1f} minutes")
print()

TIMEOUT_MINUTES = 30

if age >= TIMEOUT_MINUTES:
    print(f"✅ ORDER TIMEOUT: {age:.0f}min >= {TIMEOUT_MINUTES}min")
    print(f"   Action: CANCEL order + FIND replacement")
    print()
    print("   Scenario:")
    print("   1. Cancel XAUUSD limit order (placed 35min ago)")
    print("   2. Search best GOM verdict (exclude XAUUSD)")
    print("   3. Found: BOOM 1000 @ 67% coherence")
    print("   4. Place new BUY limit BOOM 1000 @ 13923")
    print()
    print("✅ Recycling complete!")
else:
    print(f"❌ Order still fresh: {age:.0f}min < {TIMEOUT_MINUTES}min")
    print(f"   Action: SKIP (keep monitoring)")

print()
print("=" * 70)
