@echo off
echo ========================================
echo ZONES IA COLORÉES - COMPILATION
echo ========================================
echo.
echo Nouvelles fonctionnalités:
echo - Zones BUY/SELL avec couleurs distinctives
echo - Classification PREMIUM / DISCOUNT / NEUTRAL
echo - Labels automatiques pour chaque type de zone
echo - Couleurs dynamiques selon la distance au prix
echo.
echo Légende des couleurs:
echo BUY:
echo   - Vert foncé = DISCOUNT (très bon marché)
echo   - Jaune      = PREMIUM (cher pour BUY)
echo   - Vert clair = NEUTRAL
echo.
echo SELL:
echo   - Rouge foncé = PREMIUM (très cher)
echo   - Jaune        = DISCOUNT (bon marché pour SELL)
echo   - Rouge clair  = NEUTRAL
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
    echo 🎨 ZONES IA COLORÉES ACTIVÉES 🎨
    echo ===================================
    echo Les zones IA s'affichent maintenant avec:
    echo - Couleurs distinctives pour chaque type de zone
    echo - Labels clairs (BUY PREMIUM, SELL DISCOUNT, etc.)
    echo - Bords plus épais (3 pixels) pour meilleure visibilité
    echo - Affichage sur tous les timeframes (H8, H1, M5)
    echo.
    echo 📊 Performance optimisée:
    echo - Mode UltraPerformance maintenu
    echo - Graphiques activés uniquement pour les zones IA
    echo - Tableau de bord toujours désactivé pour performance
) else (
    echo ❌ Erreur de compilation
    echo Veuillez vérifier les erreurs dans MetaEditor
)

echo.
pause
