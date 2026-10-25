@echo off
echo ========================================
echo TEST DES CORRECTIONS SL/TP BOOM/CRASH
echo ========================================
echo.
echo Corrections appliquees:
echo 1. ValidateAndAdjustStops: 300 pips minimum pour synthetiques
echo 2. EnsureStopsDistanceValid: 300 pips minimum pour synthetiques  
echo 3. CalculateSLTPInPoints: +300/600 points pour synthetiques
echo 4. CalculateSLTPInPointsWithMaxLoss: +300/600 points pour synthetiques
echo.
echo Les erreurs "Invalid stops" devraient disparaitre!
echo.
echo Instructions:
echo 1. Compilez le robot dans MetaEditor
echo 2. Redemarrez le robot sur MT5
echo 3. Surveillez les logs MT5 pour verifier les distances
echo.
echo Logs attendus:
echo - "Mode synthétique: distance minimale augmentée à 300 pips"
echo - "Mode synthétique: augmentation SL/TP à 300/600 points"
echo.
echo ========================================
echo TEST PRET!
echo ========================================
pause
