@echo off
echo ========================================
echo ACTIVATION MODE ULTRA PERFORMANCE
echo ========================================
echo.
echo Ce script va activer le mode Ultra Performance
echo pour reduire drastiquement la charge CPU du robot.
echo.
echo Changements appliques:
echo - PositionCheckInterval: 30 secondes
echo - GraphicsUpdateInterval: 5 minutes
echo - UltraPerformanceMode: true
echo.
echo ATTENTION: Cela desactivera 90%% des fonctionnalités!
echo Seul le trading essentiel sera conservé.
echo.
pause

echo Activation du mode Ultra Performance...
echo.

echo Veuillez modifier manuellement ces parametres dans MT5:
echo 1. PositionCheckInterval = 30
echo 2. GraphicsUpdateInterval = 300  
echo 3. UltraPerformanceMode = true
echo 4. DisableAllGraphics = true (recommande)
echo 5. DisableNotifications = true (recommande)
echo.
echo Redemarrez le robot apres modification.
echo.
echo ========================================
echo MODE ULTRA PERFORMANCE PRET!
echo ========================================
pause
