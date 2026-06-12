@echo off
title GOM MT5 Poller — 30s loop
cd /d D:\Dev\TradBOT
if not exist logs mkdir logs
echo [%date% %time%] GOM MT5 Poller demarre (MT5 direct, sans TradingView) >> logs\gom_mt5_poller.log

python python\gom_mt5_poller.py
