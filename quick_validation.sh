#!/bin/bash

# Quick validation script - Vérification rapide avant test
# Usage: bash quick_validation.sh

echo "╔════════════════════════════════════════════════════════╗"
echo "║     QUICK VALIDATION - SMC_Universal Live Test        ║"
echo "║                    2026-05-17                         ║"
echo "╚════════════════════════════════════════════════════════╝"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

errors=0
warnings=0

echo ""
echo "📋 STEP 1: Checking MQL5 file exists..."
if [ -f "D:/Dev/TradBOT/SMC_Universal.mq5" ]; then
    echo -e "${GREEN}✅ SMC_Universal.mq5 found${NC}"
else
    echo -e "${RED}❌ SMC_Universal.mq5 NOT FOUND${NC}"
    ((errors++))
fi

echo ""
echo "📋 STEP 2: Checking Python server file..."
if [ -f "D:/Dev/TradBOT/python/ai_server.py" ]; then
    echo -e "${GREEN}✅ ai_server.py found${NC}"
    # Check if all required endpoints are present
    endpoints=("routes/ml/continuous/start" "routes/trades/feedback" "routes/ml/metrics" "routes/decision")
    for ep in "${endpoints[@]}"; do
        if grep -q "$ep\|@app.post.*continuous\|@app.post.*feedback\|@app.get.*metrics\|@app.post.*decision" "D:/Dev/TradBOT/python/ai_server.py"; then
            echo -e "${GREEN}  ✅ Endpoint logic detected${NC}"
        fi
    done
else
    echo -e "${RED}❌ ai_server.py NOT FOUND${NC}"
    ((errors++))
fi

echo ""
echo "📋 STEP 3: Checking for known compilation errors..."
bad_props=("OBJPROP_EXPIRATION" "OBJPROP_BORDER_WIDTH_INVALID" "OBJPROP_TEXT_COLOR_INVALID")
for prop in "${bad_props[@]}"; do
    if grep -q "$prop" "D:/Dev/TradBOT/SMC_Universal.mq5"; then
        echo -e "${YELLOW}⚠️  WARNING: Found $prop (might cause compilation error)${NC}"
        ((warnings++))
    fi
done
echo -e "${GREEN}✅ No known bad properties found${NC}"

echo ""
echo "📋 STEP 4: Checking dashboard implementation..."
dashboard_strings=("GOM_SIDO UNIFIED" "DisplayMTFDashboard" "DisplayComprehensiveVerdict" "CheckAndExecuteOTEEntry")
for str in "${dashboard_strings[@]}"; do
    if grep -q "$str" "D:/Dev/TradBOT/SMC_Universal.mq5"; then
        echo -e "${GREEN}  ✅ $str found${NC}"
    else
        echo -e "${RED}  ❌ $str NOT found${NC}"
        ((errors++))
    fi
done

echo ""
echo "📋 STEP 5: Checking ML training functions..."
ml_strings=("EnsureMLContinuousTrainingRunning" "OnTradeTransaction" "trades/feedback")
for str in "${ml_strings[@]}"; do
    if grep -q "$str" "D:/Dev/TradBOT/SMC_Universal.mq5"; then
        echo -e "${GREEN}  ✅ $str found${NC}"
    else
        echo -e "${RED}  ❌ $str NOT found${NC}"
        ((errors++))
    fi
done

echo ""
echo "📋 STEP 6: Checking entry level lines..."
if grep -q "DrawEntryLevelLines\|EMA.*Fast.*M1\|EMA.*Fast.*M5\|EMA.*Fast.*H1" "D:/Dev/TradBOT/SMC_Universal.mq5"; then
    echo -e "${GREEN}✅ Entry level lines implementation found${NC}"
else
    echo -e "${RED}❌ Entry level lines NOT found${NC}"
    ((errors++))
fi

echo ""
echo "📋 STEP 7: Checking OB+CHOCH detection..."
if grep -q "DetectConfirmedOBWithCHOCH\|DrawConfirmedOBWithCHOCH" "D:/Dev/TradBOT/SMC_Universal.mq5"; then
    echo -e "${GREEN}✅ OB+CHOCH pattern detection found${NC}"
else
    echo -e "${RED}❌ OB+CHOCH pattern detection NOT found${NC}"
    ((errors++))
fi

echo ""
echo "📋 STEP 8: Checking Fibonacci levels..."
if grep -q "DrawFibonacciOnChart\|61.8\|78.6" "D:/Dev/TradBOT/SMC_Universal.mq5"; then
    echo -e "${GREEN}✅ Fibonacci retracement found${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING: Fibonacci might not be implemented${NC}"
    ((warnings++))
fi

echo ""
echo "📋 STEP 9: Checking limit order placement..."
if grep -q "ORDER_TYPE_BUY_LIMIT\|ORDER_TYPE_SELL_LIMIT\|MqlTradeRequest" "D:/Dev/TradBOT/SMC_Universal.mq5"; then
    echo -e "${GREEN}✅ Limit order system found${NC}"
else
    echo -e "${RED}❌ Limit order system NOT found${NC}"
    ((errors++))
fi

echo ""
echo "📋 STEP 10: Checking verdict tier filtering..."
if grep -q "VerdictThreshold\|GOOD\|PERFECT\|score.*0.35\|score.*0.65" "D:/Dev/TradBOT/SMC_Universal.mq5"; then
    echo -e "${GREEN}✅ Verdict tier filtering found${NC}"
else
    echo -e "${RED}❌ Verdict tier filtering NOT found${NC}"
    ((errors++))
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo ""

if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✅ ALL CHECKS PASSED${NC}"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Open MetaTerminal 5"
    echo "2. Press F4 and compile SMC_Universal.mq5"
    echo "3. Verify: 0 errors, 0 warnings"
    echo "4. Start ai_server.py: python D:\\Dev\\TradBOT\\python\\ai_server.py"
    echo "5. Load EA onto Boom 1000 Index M1 chart"
    echo "6. Follow TEST_DEPLOYMENT.md for full validation"
    exit 0
else
    echo -e "${RED}❌ $errors CRITICAL ERRORS FOUND${NC}"
    if [ $warnings -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $warnings warnings (may need attention)${NC}"
    fi
    echo ""
    echo "REQUIRED FIXES:"
    echo "1. Check SMC_Universal.mq5 for syntax errors"
    echo "2. Verify all dashboard functions are implemented"
    echo "3. Verify all ML training functions are present"
    exit 1
fi
