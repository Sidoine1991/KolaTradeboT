@echo off
REM Lancer le dashboard TradBOT moderne avec le bon PYTHONPATH
set PYTHONPATH=.
streamlit run frontend/app.py
pause 