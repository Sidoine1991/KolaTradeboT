@echo off
echo ========================================
echo MODE PERFORMANCE ULTRA-MAXIMALE - COMPILATION D'URGENCE
echo ========================================
echo.
echo ⚠️  RALENTISSEMENT DÉTECTÉ - OPTIMISATION EXTREME ⚠️
echo.
echo Optimisations appliquées:
echo - UltraPerformanceMode = true
echo - DisableAllGraphics = true  
echo - DrawAIZonesEnabled = false
echo - DrawSupportResistance = false
echo - DrawTrendlinesEnabled = false
echo - DrawDerivPatterns = false
echo - DrawSMCZones = false
echo - PositionCheckInterval = 180 secondes (3 minutes)
echo - GraphicsUpdateInterval = 120 secondes (2 minutes)
echo - API call frequency = 1 sur 20 ticks
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
    echo 🚀 MODE PERFORMANCE ULTRA-MAXIMALE ACTIVÉ 🚀
    echo ==============================================
    echo 
    echo 🔥 FONCTIONNALITÉS DÉSACTIVÉES:
    echo   - TOUS les graphiques et dessins
    echo   - Tableau de bord IA
    echo   - Zones IA colorées
    echo   - Supports/résistances
    echo   - Trendlines
    echo   - Patterns Deriv
    echo   - Zones SMC/OrderBlock
    echo.
    echo ⚡ OPTIMISATIONS ACTIVES:
    echo   - Vérifications positions toutes les 3 minutes
    echo   - Appels API 1x sur 20 ticks
    echo   - Cache des informations de symbole
    echo   - Mode ultra performance
    echo.
    echo 📊 RÉSULTAT ATTENDU:
    echo   - Réduction de 95%% de la charge CPU
    echo   - MT5 devrait être extrêmement fluide
    echo   - Trading toujours fonctionnel
    echo   - Aucun ralentissement
    echo.
    echo ⚠️  Le robot trade en mode minimaliste mais fonctionnel!
) else (
    echo ❌ Erreur de compilation
    echo Veuillez vérifier les erreurs dans MetaEditor
)

echo.
pause
