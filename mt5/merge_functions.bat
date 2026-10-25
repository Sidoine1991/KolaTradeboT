@echo off
echo Fusion de fx_robot.mq5 avec les fonctions avancées...

set ORIGINAL_FILE=fx_robot.mq5
set FUNCTIONS_FILE=advanced_functions.mqh
set BACKUP_FILE=fx_robot_backup_%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%.mq5

echo.
echo 1. Sauvegarde du fichier original...
copy %ORIGINAL_FILE% %BACKUP_FILE% >nul
if %ERRORLEVEL% NEQ 0 (
    echo ERREUR: Impossible de sauvegarder le fichier original
    pause
    exit /b 1
)

echo    ✓ Fichier sauvegardé: %BACKUP_FILE%

echo.
echo 2. Fusion avec les fonctions avancées...
copy /b %ORIGINAL_FILE% + %FUNCTIONS_FILE% fx_robot_complete.mq5 >nul
if %ERRORLEVEL% NEQ 0 (
    echo ERREUR: Impossible de fusionner les fichiers
    pause
    exit /b 1
)

echo    ✓ Fichiers fusionnés: fx_robot_complete.mq5

echo.
echo 3. Remplacement du fichier original...
move /y fx_robot_complete.mq5 %ORIGINAL_FILE% >nul
if %ERRORLEVEL% NEQ 0 (
    echo ERREUR: Impossible de remplacer le fichier original
    pause
    exit /b 1
)

echo    ✓ Fichier original mis à jour

echo.
echo 4. Nettoyage...
del %FUNCTIONS_FILE% >nul

echo.
echo ========================================
echo FUSION REUSSIE!
echo ========================================
echo.
echo Le fichier fx_robot.mq5 contient maintenant:
echo - Toutes les fonctions originales
echo - Toutes les fonctions de détection avancées
echo - ScientificSpikeDetection complet
echo - 13 indicateurs techniques
echo.
echo Fonctions ajoutées:
echo ✓ CalculateAdvancedStatistics
echo ✓ DetectScissorPattern
echo ✓ DetectFractalSpike
echo ✓ ComputeVPIN
echo ✓ DetectPriceGap
echo ✓ DetectHammerPattern
echo ✓ DetectEngulfingPattern
echo ✓ DetectBollingerSqueeze
echo ✓ DetectBollingerBreakout
echo ✓ GetRSI
echo ✓ GetMACDSignal
echo ✓ ScientificSpikeDetection
echo.
echo Vous pouvez maintenant compiler fx_robot.mq5!
echo.

pause
