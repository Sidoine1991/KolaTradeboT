#!/bin/bash
# Monitor GOM sync daemon — show new cycles as they arrive

LOG_FILE="logs/gom_sync_daemon_10min.log"
LAST_LINES=0

echo "🔍 GOM Sync Daemon Monitor (Ctrl+C to stop)"
echo "=================================================="
echo ""

while true; do
    CURRENT_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    
    if [ "$CURRENT_LINES" -gt "$LAST_LINES" ]; then
        DIFF=$((CURRENT_LINES - LAST_LINES))
        echo "📍 New lines detected: $DIFF"
        
        # Show last cycle marker
        grep -E "GOM SYNC CYCLE|Sync completed|Next sync in" "$LOG_FILE" | tail -3
        echo ""
        
        LAST_LINES=$CURRENT_LINES
    fi
    
    sleep 5
done
