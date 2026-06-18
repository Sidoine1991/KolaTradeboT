#!/bin/bash
# Boucle GOM Sync + Report toutes les 10 minutes
cd D:/Dev/TradBOT

echo "[START] GOM Sync Daemon — Boucle 10 minutes"
echo "Logs → logs/gom_sync.log"
echo ""

INTERVAL=600  # 10 minutes en secondes

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] Exécution synchronisation GOM..."
    
    python python/gom_sync_with_report.py --report >> logs/gom_sync_loop.log 2>&1
    
    NEXT_TIME=$(date -d "+$INTERVAL seconds" '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] Prochaine exécution à $NEXT_TIME"
    echo "---" >> logs/gom_sync_loop.log
    
    sleep $INTERVAL
done
