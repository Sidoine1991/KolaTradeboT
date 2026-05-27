@echo off
REM ═══════════════════════════════════════════════════════════════
REM TradBOT — Morning Market Scanner
REM Lancé automatiquement par Windows Task Scheduler à 07h00 UTC
REM ═══════════════════════════════════════════════════════════════

cd /d "D:\Dev\TradBOT"

REM Log de démarrage
echo [%DATE% %TIME%] Morning Scan démarré >> logs\morning_scan.log

REM Lancer Claude Code avec le prompt morning scan
claude --print "MORNING MARKET SCANNER — 07h00 UTC

Lance la routine Morning Scan de l'agent trading-system-optimizer.

Exécute les étapes suivantes dans l'ordre :

1. Connecte-toi à TradingView via MCP (tv_health_check, tv_launch si nécessaire)
2. Scan les 9 symboles : EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD, NZDUSD, XAUUSD, US30
   - Pour chaque symbole : chart_set_symbol → H1 → data_get_study_values (GOM KOLA SIDO + GOM·MTF) → data_get_pine_labels → quote_get → H4 pour confirmation HTF
3. Evalue chaque symbole selon les critères SMC/ICT : BOS/CHoCH + OTE (61.8-78.6%) + OB + MTF aligné
4. Calcule Entry/SL/TP1/TP2 avec RR minimum 1.5 pour les setups qualifiés
5. Dessine les setups sur TradingView (rectangle OTE + horizontal lines SL/TP + label texte)
6. Envoie UN SEUL message WhatsApp recap via POST http://127.0.0.1:8000/notify-whatsapp avec toutes les paires opportunes + niveaux + RR
7. Envoie un second message WhatsApp avec les commandes bridge a lancer pour les paires qualifiées
8. Ecrit le log dans data/logs/daily/YYYY-MM-DD.md" >> logs\morning_scan.log 2>&1

echo [%DATE% %TIME%] Morning Scan terminé >> logs\morning_scan.log
