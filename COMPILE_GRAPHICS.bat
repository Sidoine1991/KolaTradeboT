@echo off
echo Compilation de F_INX_Scalper_double.mq5 avec optimisations performance et graphiques activés...
cd /d "d:\Dev\TradBOT"

REM Chercher MetaEditor dans les emplacements courants
if exist "C:\Program Files\MetaTrader 5\metaeditor64.exe" (
    echo MetaEditor trouvé dans Program Files
    "C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile "F_INX_Scalper_double.mq5"
    goto :check_result
) else if exist "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe" (
    echo MetaEditor trouvé dans Program Files (x86)
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe" /compile "F_INX_Scalper_double.mq5"
    goto :check_result
) else (
    echo Recherche de MetaEditor dans d'autres emplacements...
    for /r "C:\" %%f in (metaeditor64.exe) do (
        if exist "%%f" (
            echo MetaEditor trouvé: %%f
            "%%f" /compile "F_INX_Scalper_double.mq5"
            goto :check_result
        )
    )
)

:check_result
echo.
echo Vérification de la compilation...
if exist "d:\Dev\TradBOT\F_INX_Scalper_double.ex5" (
    echo ✅ Compilation réussie!
    echo Fichier compilé: F_INX_Scalper_double.ex5
    echo.
    echo Paramètres modifiés:
    echo - UltraPerformanceMode: false (activé graphiques)
    echo - DisableAllGraphics: false (activé graphiques)
    echo - ShowInfoOnChart: true (tableau de bord visible)
    echo - GraphicsUpdateInterval: 30s (rafraîchissement rapide)
    echo - Cache SymbolInfoDouble activé (optimisation CPU)
) else (
    echo ❌ Erreur de compilation
    echo Veuillez compiler manuellement dans MetaEditor
)

echo.
pause
