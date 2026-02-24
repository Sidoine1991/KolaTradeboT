@echo off
echo ========================================
echo COMPILATION - F_INX_Scalper_double.mq5
echo ========================================
echo.

echo 🔧 Recherche de MetaEditor...
set METAPATH=""
for %%f in (
    "C:\Program Files\MetaTrader 5\metaeditor64.exe"
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"
) do (
    if exist %%f (
        set METAPATH=%%f
        echo ✅ MetaEditor trouvé: %%f
        goto :compile
    )
)

:compile
if "%METAPATH%"=="" (
    echo ❌ MetaEditor non trouvé
    echo.
    echo 🔧 Veuillez installer MetaTrader 5
    goto :end
)

echo.
echo 📝 Compilation de F_INX_Scalper_double.mq5...
echo.

REM Créer un fichier de log pour la compilation
echo Compilation en cours... > compile_log.txt

REM Compiler avec affichage des erreurs
"%METAPATH%" /compile "F_INX_Scalper_double.mq5" /log:compile_log.txt /close

timeout /t 3 /nobreak >nul

REM Vérifier si le fichier .ex5 a été créé
if exist "F_INX_Scalper_double.ex5" (
    echo.
    echo ✅ COMPILATION RÉUSSIE!
    echo 📁 Fichier créé: F_INX_Scalper_double.ex5
    echo.
    
    REM Afficher la taille du fichier
    for %%F in ("F_INX_Scalper_double.ex5") do (
        set size=%%~zF
        echo 📊 Taille: %%~zF octets
    )
    
    echo.
    echo 🚀 DÉPLOIEMENT:
    echo 1. Copiez F_INX_Scalper_double.ex5 dans MT5/MQL5/Experts/
    echo 2. Redémarrez MetaTrader 5
    echo 3. Attachez au graphique F_INX
    echo.
    
) else (
    echo.
    echo ❌ ÉCHEC DE LA COMPILATION
    echo.
    echo 📋 Log de compilation:
    type compile_log.txt
    echo.
    echo 🔧 Vérifiez les erreurs ci-dessus dans MetaEditor
    echo.
    echo 📝 Ouvrez manuellement MetaEditor:
    echo 1. Fichier ^> Ouvrir ^> F_INX_Scalper_double.mq5
    echo 2. Compiler (F7)
    echo 3. Corrigez les erreurs affichées
)

:end
echo.
pause
