@echo off
setlocal enabledelayedexpansion

echo ════════════════════════════════════════════════════════════════
echo 🔄 RESTART MT5 + RECOMPILE EAs
echo ════════════════════════════════════════════════════════════════

REM Fermer MT5 existant
echo [1/5] Fermeture MT5...
taskkill /F /IM terminal64.exe 2>nul
taskkill /F /IM MetaEditor64.exe 2>nul
timeout /T 3 /nobreak

REM Lancer MT5
echo [2/5] Démarrage MT5...
start "" "C:\Program Files\MetaTrader 5\terminal64.exe"
timeout /T 8 /nobreak

REM Lancer MetaEditor
echo [3/5] Ouverture MetaEditor...
start "" "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
timeout /T 5 /nobreak

REM Recompiler TradeManager
echo [4/5] Recompilant TradeManager.mq5...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$editor = Get-Process | Where-Object {$_.Name -eq 'MetaEditor64'}; if ($editor) { " ^
  "Write-Host 'MetaEditor lancé (PID:' $editor.Id ')'; " ^
  "[void][System.Windows.Forms.SendKeys]::SendWait('%%^(d:Dev:TradBOT:TradeManager.mq5%%)'); " ^
  "timeout 2; " ^
  "[void][System.Windows.Forms.SendKeys]::SendWait('{F9}'); " ^
  "timeout 5; }" 2>nul

REM Recompiler SpikeRiderEA
echo [5/5] Recompilant SpikeRiderEA.mq5...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[void][System.Windows.Forms.SendKeys]::SendWait('%%^(d:Dev:TradBOT:SpikeRiderEA.mq5%%)'); " ^
  "timeout 2; " ^
  "[void][System.Windows.Forms.SendKeys]::SendWait('{F9}'); " ^
  "timeout 5;" 2>nul

echo.
echo ════════════════════════════════════════════════════════════════
echo ✅ Recompilation complète!
echo.
echo 📋 Vérifier:
echo   1. MetaEditor - Pas d'erreurs de compilation
echo   2. MT5 Terminal - EAs attachés aux charts
echo   3. Logs - "[GOM-Auto]" et "[SpikeRider]" messages
echo.
echo ════════════════════════════════════════════════════════════════
pause
