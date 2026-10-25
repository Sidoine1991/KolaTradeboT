@echo off
echo Compilation de Fx_robot.mq5...
echo.

REM Utiliser le chemin exact de MetaTrader 5
set METAEEDITOR_PATH="D:\Program Files\MetaTrader 5\metaeditor.exe"

if exist %METAEEDITOR_PATH% (
    echo MetaEditor trouvé: %METAEEDITOR_PATH%
    echo.
) else (
    echo MetaEditor non trouvé à: %METAEEDITOR_PATH%
    pause
    exit /b 1
)

REM Compiler le fichier
echo Compilation en cours...
%METAEEDITOR_PATH% /compile:Fx_robot.mq5 /log:compile_log.txt

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo ✅ COMPILATION RÉUSSIE!
    echo ========================================
    echo.
    echo Le fichier Fx_robot.mq5 a été compilé avec succès.
    echo Vous pouvez maintenant l'utiliser dans MetaTrader 5.
    echo.
) else (
    echo.
    echo ========================================
    echo ❌ ERREUR DE COMPILATION!
    echo ========================================
    echo.
    echo Code d'erreur: %ERRORLEVEL%
    echo Voir compile_log.txt pour les détails
    echo.
    echo Contenu du fichier de log:
    echo ----------------------------------------
    if exist compile_log.txt (
        type compile_log.txt
    ) else (
        echo Fichier de log non trouvé
    )
    echo.
)

pause
