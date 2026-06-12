@echo off
cd /d D:\Dev\TradBOT
set PYTHONHOME=C:\Users\USER\AppData\Local\Programs\Python\Python311_9
set PYTHONPATH=
"C:\Users\USER\AppData\Local\Programs\Python\Python311_9\python.exe" -u Python/pipeline_hourly_autonomous.py --once 2>&1
