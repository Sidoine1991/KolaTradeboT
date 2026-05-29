@echo off
setlocal enabledelayedexpansion

REM ════════════════════════════════════════════════════════════════
REM 🚀 FORCE RELOAD EAs — Ferme MT5 + Relance + Force Recompile
REM ════════════════════════════════════════════════════════════════

echo.
echo [Step 1/6] Fermeture forcée de MT5 et MetaEditor...
taskkill /F /IM terminal64.exe >/dev/null 2>&1
taskkill /F /IM MetaEditor64.exe >/dev/null 2>&1
timeout /T 2 /nobreak

echo [Step 2/6] Suppression du cache compilé (force recompile)...
REM Supprimer les anciens .ex5 pour forcer une recompilation
del "C:\Users\%USERNAME%\AppData\Roaming\MetaQuotes\Terminal\Common\Files\*.ex5" /Q 2>/dev/null
echo    ✓ Cache nettoyé

echo [Step 3/6] Lancement de MetaEditor (compilation)...
REM Lancer MetaEditor qui va recompiler les .mq5
start "" "C:\Program Files\MetaTrader 5\MetaEditor64.exe" "D:\Dev\TradBOT\TradeManager.mq5"
timeout /T 3 /nobreak

REM Attendre que MetaEditor se charge
echo [Step 4/6] Compilation TradeManager (F9)...
powershell -NoProfile -Command ^
  "Add-Type -AssemblyName System.Windows.Forms; " ^
  "[System.Windows.Forms.SendKeys]::SendWait('{F9}'); " ^
  "Start-Sleep -Seconds 6"

echo [Step 5/6] Ouverture de SpikeRiderEA...
powershell -NoProfile -Command ^
  "Add-Type -AssemblyName System.Windows.Forms; " ^
  "[System.Windows.Forms.SendKeys]::SendWait('^o'); " ^
  "Start-Sleep -Seconds 2; " ^
  "[System.Windows.Forms.SendKeys]::SendWait('D:\Dev\TradBOT\SpikeRiderEA.mq5{ENTER}'); " ^
  "Start-Sleep -Seconds 3; " ^
  "[System.Windows.Forms.SendKeys]::SendWait('{F9}'); " ^
  "Start-Sleep -Seconds 6"

echo [Step 6/6] Lancement de MT5...
timeout /T 3 /nobreak
start "" "C:\Program Files\MetaTrader 5\terminal64.exe"
timeout /T 10 /nobreak

echo.
echo ════════════════════════════════════════════════════════════════
echo ✅ Recompilation forcée complète!
echo.
echo 📋 Vérifications à faire dans MT5:
echo   1. Terminal -> Experts -> Allow algorithmic trading = ON
echo   2. Terminal -> Connect to server = OK (couleur verte)
echo   3. Charts -> Attacher TradeManager sur XAUUSD M1
echo   4. Charts -> Attacher SpikeRiderEA sur Boom 600 M1
echo   5. Logs (F2) -> Chercher "[GOM-Auto]" et "[SpikeRider]" messages
echo.
echo 🎯 Si toujours pas de trades:
echo   - Vérifier les paramètres dans MT5 (Inputs tab)
echo   - Confirmer GOMBlockOnWait = false (cochée: non)
echo   - Relancer les EAs (detach/attach)
echo ════════════════════════════════════════════════════════════════
pause
