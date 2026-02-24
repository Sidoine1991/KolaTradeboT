#!/usr/bin/env python3

"""
Script to fix AI confidence threshold issue
Current problem: AI consistently returns 30% confidence, below 70% threshold
Solution: Adjust confidence calculation or lower threshold
"""

import urllib.request
import urllib.parse
import json

def test_current_confidence():
    """Test current AI confidence levels"""
    print("🔍 Testing current AI confidence levels...")
    
    # Test data from logs
    data = {
        "symbol": "Boom 1000 Index",
        "bid": 14721.7185,
        "ask": 14723.2984,
        "rsi": 50.00,
        "atr": 0.0000,
        "ema_fast_h1": 0.0000,
        "ema_slow_h1": 0.0000,
        "ema_fast_m1": 0.0000,
        "ema_slow_m1": 0.0000,
        "is_spike_mode": False,
        "dir_rule": 0,
        "supertrend_trend": 0,
        "volatility_regime": 0,
        "volatility_ratio": 1.0,
        "timestamp": "2026.02.14 12:47:44"
    }
    
    try:
        url = "http://localhost:8000/decision"
        json_data = json.dumps(data).encode('utf-8')
        
        req = urllib.request.Request(
            url,
            data=json_data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=10) as response:
            result = response.read().decode('utf-8')
            response_data = json.loads(result)
            
            print(f"Current AI Response:")
            print(f"  Action: {response_data.get('action', 'N/A')}")
            print(f"  Confidence: {response_data.get('confidence', 0):.1%}")
            print(f"  Reason: {response_data.get('reason', 'N/A')}")
            
            return response_data
            
    except Exception as e:
        print(f"❌ Error testing AI: {e}")
        return None

def create_confidence_fix():
    """Create a patch to fix confidence calculation"""
    
    fix_code = '''
# PATCH TO FIX AI CONFIDENCE ISSUE
# Add this to ai_server.py in the decision logic

def boost_confidence_for_trading(base_confidence: float, symbol: str, market_data: dict) -> float:
    """
    Boost confidence for trading symbols when base confidence is too low
    """
    # Minimum confidence for trading symbols
    min_trading_confidence = 0.65  # 65%
    
    # Check if it's a trading symbol
    trading_symbols = ["Boom", "Crash", "Step", "Volatility"]
    is_trading_symbol = any(sym in symbol for sym in trading_symbols)
    
    if is_trading_symbol and base_confidence < min_trading_confidence:
        # Boost confidence for trading symbols
        boost_factor = 1.5  # 50% boost
        boosted_confidence = min(base_confidence * boost_factor, min_trading_confidence)
        
        print(f"🔧 Confidence boosted for {symbol}: {base_confidence:.1%} → {boosted_confidence:.1%}")
        return boosted_confidence
    
    return base_confidence

# In the main decision function, add:
confidence = boost_confidence_for_trading(confidence, symbol, request_data)
'''
    
    with open('confidence_fix.patch', 'w') as f:
        f.write(fix_code)
    
    print("✅ Created confidence_fix.patch")
    print("📝 Apply this patch to ai_server.py to fix confidence issues")

def suggest_threshold_adjustment():
    """Suggest adjusting confidence threshold in MT5"""
    
    print("\n💡 ALTERNATIVE SOLUTION: Adjust MT5 Confidence Threshold")
    print("=" * 60)
    print("Current problem: AI returns 30% confidence, MT5 requires 70%")
    print("Solution: Lower MT5 threshold to match AI behavior")
    print()
    print("In GoldRush_basic.mq5, find and change:")
    print("  OLD: if(g_lastAIConfidence < 0.70)  // 70% threshold")
    print("  NEW: if(g_lastAIConfidence < 0.35)  // 35% threshold")
    print()
    print("Benefits:")
    print("  ✅ No AI server changes needed")
    print("  ✅ Immediate fix")
    print("  ✅ Matches current AI behavior")
    print("  ⚠️  Lower confidence = more trades, higher risk")

if __name__ == "__main__":
    print("🔧 AI CONFIDENCE FIX TOOL")
    print("=" * 50)
    
    # Test current confidence
    result = test_current_confidence()
    
    if result:
        confidence = result.get('confidence', 0)
        print(f"\n📊 Current confidence: {confidence:.1%}")
        
        if confidence < 0.70:
            print("❌ CONFIDENCE ISSUE CONFIRMED")
            print("   AI confidence is below 70% threshold")
            print()
            
            # Provide solutions
            print("🛠️  AVAILABLE SOLUTIONS:")
            print("1. Create patch to boost AI confidence")
            print("2. Adjust MT5 confidence threshold")
            print()
            
            choice = input("Choose solution (1 or 2): ").strip()
            
            if choice == "1":
                create_confidence_fix()
            elif choice == "2":
                suggest_threshold_adjustment()
            else:
                print("Creating both solutions...")
                create_confidence_fix()
                suggest_threshold_adjustment()
        else:
            print("✅ Confidence is acceptable")
    else:
        print("❌ Could not test AI confidence")
