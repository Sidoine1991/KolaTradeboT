@echo off
echo Compilation de F_INX_Scalper_double.mq5 avec corrections du tableau de bord...
cd /d "d:\Dev\TradBOT"

REM Chercher MetaEditor dans les emplacements courants
if exist "C:\Program Files\MetaTrader 5\metaeditor64.exe" (
    echo MetaEditor trouvé dans Program Files
    "C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile "F_INX_Scalper_double.mq5" /close
    goto :check_result
) else if exist "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe" (
    echo MetaEditor trouvé dans Program Files (x86)
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe" /compile "F_INX_Scalper_double.mq5" /close
    goto :check_result
) else (
    echo Recherche de MetaEditor dans d'autres emplacements...
    for /r "C:\" %%f in (metaeditor64.exe) do (
        if exist "%%f" (
            echo MetaEditor trouvé: %%f
            "%%f" /compile "F_INX_Scalper_double.mq5" /close
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
    echo Corrections appliquées:
    echo - Suppression de la fonction UpdateSymbolCache dupliquée
    echo - Correction des variables de cache (g_cached*)
    echo - Forçage de l'affichage du tableau de bord
    echo - Suppression de la condition UltraPerformanceMode
    echo - Initialisation forcée du dashboard au premier tick
    echo.
    echo Le tableau de bord devrait maintenant s'afficher en bas à gauche.
) else (
    echo ❌ Erreur de compilation
    echo Veuillez vérifier les erreurs dans MetaEditor
)

echo.
pause
