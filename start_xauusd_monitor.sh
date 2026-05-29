#!/bin/bash
# Start XAUUSD 20-min WhatsApp surveillance system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/xauusd_monitor.py"
LOG_FILE="$SCRIPT_DIR/xauusd_monitor.log"

echo "🚀 Starting XAUUSD 20-min WhatsApp Monitor..."
echo "📝 Logs: $LOG_FILE"
echo "📋 Config: $SCRIPT_DIR/xauusd_monitor_config.json"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found"
    exit 1
fi

# Check dependencies
python3 -c "import httpx" 2>/dev/null || {
    echo "⚠️  Installing httpx..."
    pip install httpx -q
}

# Start monitor in background
cd "$SCRIPT_DIR"
nohup python3 "$PYTHON_SCRIPT" >> "$LOG_FILE" 2>&1 &

MONITOR_PID=$!
echo "✅ Monitor started with PID $MONITOR_PID"
echo "🛑 To stop: kill $MONITOR_PID"

# Save PID for reference
echo "$MONITOR_PID" > "$SCRIPT_DIR/.xauusd_monitor.pid"

# Show first few lines of logs
sleep 2
echo ""
echo "📊 Recent logs:"
tail -n 5 "$LOG_FILE"
