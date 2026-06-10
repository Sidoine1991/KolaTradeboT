#!/bin/bash
# SMC_Universal v3.0 — Quick Start Script
# Launches all components for production trading

set -e

PROJECT_DIR="D:\Dev\TradBOT"
MT5_PATH="C:\Program Files\MetaTrader 5"

echo "════════════════════════════════════════════════════════════"
echo "  🚀 SMC_Universal v3.0 — Quick Start"
echo "════════════════════════════════════════════════════════════"
echo ""

# Step 1: Check files
echo "✓ Step 1: Checking files..."
if [ ! -f "$PROJECT_DIR/mt5/SMC_Universal_PROD.mq5" ]; then
    echo "❌ ERROR: SMC_Universal_PROD.mq5 not found"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/modules/SMC_TVBridge.mqh" ]; then
    echo "❌ ERROR: SMC_TVBridge.mqh not found"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/Python/gom_verdict_poller.py" ]; then
    echo "❌ ERROR: gom_verdict_poller.py not found"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/Python/tv_snapshot_poller.py" ]; then
    echo "❌ ERROR: tv_snapshot_poller.py not found"
    exit 1
fi

echo "✅ All files present"
echo ""

# Step 2: Create data directory
echo "✓ Step 2: Setting up data directory..."
mkdir -p "$PROJECT_DIR/data"
echo "✅ data/ directory ready"
echo ""

# Step 3: Copy to MT5
echo "✓ Step 3: Copying files to MT5..."
cp "$PROJECT_DIR/mt5/SMC_Universal_PROD.mq5" \
   "$MT5_PATH/MQL5/Experts/SMC_Universal.mq5" 2>/dev/null || \
   echo "⚠️  Could not copy to MT5 (check path or permissions)"

cp "$PROJECT_DIR/modules/SMC_TVBridge.mqh" \
   "$MT5_PATH/MQL5/Include/SMC_TVBridge.mqh" 2>/dev/null || \
   echo "⚠️  Could not copy module (check path or permissions)"

echo "✅ Files staged for MT5"
echo ""

# Step 4: Check Python
echo "✓ Step 4: Checking Python..."
if ! command -v python &> /dev/null; then
    echo "❌ ERROR: Python not found. Install Python 3.8+"
    exit 1
fi

PYTHON_VERSION=$(python --version 2>&1 | awk '{print $2}')
echo "✅ Python $PYTHON_VERSION found"
echo ""

# Step 5: Virtual environment
echo "✓ Step 5: Setting up Python environment..."
if [ ! -d "$PROJECT_DIR/venv" ]; then
    cd "$PROJECT_DIR"
    python -m venv venv
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment exists"
fi

cd "$PROJECT_DIR"
source venv/Scripts/activate 2>/dev/null || source venv/bin/activate

echo "✅ Python environment activated"
echo ""

# Step 6: Launch pollers (background)
echo "✓ Step 6: Launching pollers..."
echo ""
echo "  Terminal 1 (GOM Poller):"
echo "  ========================"
echo "  cd $PROJECT_DIR"
echo "  python Python/gom_verdict_poller.py --interval 10 --symbol 'Boom 500 Index'"
echo ""
echo "  Terminal 2 (TV Poller):"
echo "  ======================="
echo "  cd $PROJECT_DIR"
echo "  python Python/tv_snapshot_poller.py --symbol 'Boom 500 Index' --interval 5"
echo ""
echo "  → Run these commands in NEW terminal windows"
echo ""

# Step 7: MT5 instructions
echo "✓ Step 7: MT5 Setup Instructions:"
echo "======================================"
echo ""
echo "1. Open MetaTrader 5"
echo "2. Open chart: Boom 500 Index M1"
echo "3. Insert → Expert Advisors → SMC_Universal"
echo "4. Parameters:"
echo "   - UseCapitalManager: true"
echo "   - MinConfluenceScore: 4"
echo "   - ApplySymmetryRules: true"
echo "   - InpDebug: false (true for testing)"
echo "5. Click OK"
echo ""

# Step 8: Verification
echo "✓ Step 8: Verification Checklist:"
echo "===================================="
echo ""
echo "  [ ] data/gom_signal.json updated (< 15s old)"
echo "  [ ] data/tv_snapshot.json updated (< 15s old)"
echo "  [ ] MT5 dashboard shows GOM verdict"
echo "  [ ] Confluence score visible (0-7)"
echo "  [ ] No errors in MT5 logs"
echo ""

# Step 9: Status
echo "════════════════════════════════════════════════════════════"
echo "✅ SMC_Universal v3.0 is ready!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📖 Documentation:"
echo "  - Full integration: INTEGRATION_SMC_UNIVERSAL_v3.md"
echo "  - Test suite: TEST_SMC_UNIVERSAL_v3.md"
echo "  - Delivery report: SMC_UNIVERSAL_v3_DELIVERY.md"
echo ""
echo "🚀 Next:"
echo "  1. Open 2 new terminal windows"
echo "  2. Start both pollers"
echo "  3. Attach EA to MT5 chart"
echo "  4. Monitor logs for 30 minutes"
echo ""
echo "════════════════════════════════════════════════════════════"
