@echo off
chcp 65001 > nul
cd /d D:\Dev\TradBOT
python Python\tradbot_monitor.py --phone +2290196911346 --poll 60 --whatsapp 600
