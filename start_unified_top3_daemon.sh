#!/bin/bash
# Bash Script: Start Unified TOP 3 Daemon
# Lance le daemon qui envoie UN SEUL rapport consolidé toutes les 20 minutes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/scripts/unified_top3_daemon.py"
LOG_FILE="$SCRIPT_DIR/unified_top3_daemon.log"

if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "ERROR: Script not found: $PYTHON_SCRIPT"
    exit 1
fi

echo "============================================================"
echo "Starting Unified TOP 3 Daemon"
echo "Script: $PYTHON_SCRIPT"
echo "Log: $LOG_FILE"
echo "============================================================"

# Lancer en arrière-plan avec redirection des logs
nohup python3 "$PYTHON_SCRIPT" > "$LOG_FILE" 2>&1 &
PID=$!

echo "Daemon started (PID: $PID)"
echo "Logs:"
echo ""

# Afficher les logs en temps réel
tail -f "$LOG_FILE"
