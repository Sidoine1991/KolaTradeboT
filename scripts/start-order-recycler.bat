@echo off
REM start-order-recycler.bat
REM Démarre l'Order Recycler en boucle continue (check toutes les 5min)

setlocal enabledelayedexpansion

echo.
echo =====================================================
echo  TRADBOT ORDER RECYCLER - Monitoring & Recycle
echo =====================================================
echo.
echo Ce processus:
echo   1. Monitor les ordres limit pending
echo   2. Si age >= 30min, annule l'ordre
echo   3. Recherche meilleur verdict GOM sur autre symbol
echo   4. Place nouvel ordre limit sur meilleur signal
echo.
echo Résultat: Ordres stale annulés + ordres frais placés
echo Fréquence: Toutes les 5 minutes
echo.

cd /d D:\Dev\TradBOT

echo Lancement Order Recycler en boucle...
echo.

python Python/order_recycler.py --loop

echo.
echo Order Recycler arrêté
pause
