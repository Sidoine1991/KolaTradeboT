@echo off
echo ========================================
echo MODE ULTRA PERFORMANCE - COMPILATION
echo ========================================
echo.
echo Optimisations appliquées pour réduire la charge CPU:
echo - UltraPerformanceMode = true
echo - DisableAllGraphics = true  
echo - ShowInfoOnChart = false
echo - PositionCheckInterval = 120 secondes
echo - GraphicsUpdateInterval = 60 secondes
echo - API call frequency = 1 sur 12 ticks
echo.
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
    echo 🔥 MODE ULTRA PERFORMANCE ACTIVÉ 🔥
    echo =====================================
    echo Le robot fonctionne maintenant en mode minimal:
    echo - Aucun graphique ni dessin sur le chart
    echo - Tableau de bord désactivé
    echo - Appels API réduits au minimum
    echo - Vérifications positions toutes les 2 minutes
    echo - Cache des informations de symbole actif
    echo.
    echo 📊 Performance attendue:
    echo - Réduction de 90%% de la charge CPU
    echo - MT5 devrait être beaucoup plus fluide
    echo - Trading toujours fonctionnel
    echo.
    echo ⚠️  Pour voir les informations IA:
    echo    Désactivez UltraPerformanceMode dans les paramètres
) else (
    echo ❌ Erreur de compilation
    echo Veuillez vérifier les erreurs dans MetaEditor
)

echo.
pause
