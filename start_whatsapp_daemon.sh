#!/bin/bash
# Bash Script: Start WhatsApp Report Daemon
# Lance le script Python en arrière-plan avec logs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/scripts/whatsapp_report_daemon.py"
LOG_FILE="$SCRIPT_DIR/whatsapp_daemon.log"

if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "❌ Script not found: $PYTHON_SCRIPT"
    exit 1
fi

echo "================================================================"
echo "🚀 Démarrage WhatsApp Report Daemon"
echo "Script: $PYTHON_SCRIPT"
echo "Log: $LOG_FILE"
echo "================================================================"

# Lancer en arrière-plan avec redirection des logs
nohup python3 "$PYTHON_SCRIPT" > "$LOG_FILE" 2>&1 &
PID=$!

echo "✅ Daemon lancé (PID: $PID)"
echo "📋 Logs en temps réel:"
echo ""

# Afficher les logs en temps réel
tail -f "$LOG_FILE"
