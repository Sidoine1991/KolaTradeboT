@echo off
echo ========================================
echo OPTIMISATION ULTRA PERFORMANCE - MT5
echo ========================================
echo.
echo 🔧 CONFIGURATION OPTIMALE POUR MT5 LÉGER:
echo.
echo 1. MODE ULTRA PERFORMANCE ACTIVÉ:
echo    ✅ UltraPerformanceMode = true
echo    ✅ HighPerformanceMode = true
echo    ✅ DisableAllGraphics = true
echo    ✅ DisableNotifications = true
echo.
echo 2. INTERVALS AUGMENTÉS:
echo    ✅ PositionCheckInterval = 120 (2 minutes)
echo    ✅ GraphicsUpdateInterval = 1200 (20 minutes)
echo    ✅ AI_UpdateInterval = 20 (20 secondes)
echo.
echo 3. FONCTIONNALITÉS DÉSACTIVÉES:
echo    ❌ DrawTrendlines = false
echo    ❌ DrawSMCZones = false
echo    ❌ DrawDerivPatterns = false
echo    ❌ DrawSupportResistance = false
echo    ❌ DrawAIZones = false
echo    ❌ ShowDashboard = false
echo    ❌ ShowInfoOnChart = false
echo    ❌ DebugMode = false
echo.
echo 4. API RÉDUITS:
echo    ❌ UseAllEndpoints = false
echo    ❌ UseAdvancedDecisionGemma = false
echo    ❌ UseTrendAPIAnalysis = false
echo.
echo ⚡ RÉSULTAT ATTENDU:
echo    - MT5 ultra réactif
echo    - CPU réduit de 90%%
echo    - Plus de ralentissements
echo    - Trading fonctionnel
echo.
echo ========================================
echo APPLIQUER LA CONFIGURATION ULTRA...
echo ========================================
echo.

REM Créer le fichier de configuration optimisé
echo // Configuration Ultra Performance pour MT5 > config_ultra.mq5
echo input group "=== ULTRA PERFORMANCE ===" >> config_ultra.mq5
echo input bool   UltraPerformanceMode = true;     // Mode ultra performance (désactive 90%% des fonctionnalités) >> config_ultra.mq5
echo input bool   HighPerformanceMode = true;     // Mode haute performance (réduit charge CPU) >> config_ultra.mq5
echo input bool   DisableAllGraphics = true;      // Désactiver tous les graphiques (performance maximale) >> config_ultra.mq5
echo input bool   DisableNotifications = true;      // Désactiver les notifications (performance) >> config_ultra.mq5
echo input int    PositionCheckInterval = 120;    // Intervalle vérification positions (secondes) >> config_ultra.mq5
echo input int    GraphicsUpdateInterval = 1200;  // Intervalle mise à jour graphiques (secondes) >> config_ultra.mq5
echo input int    AI_UpdateInterval = 20;          // Intervalle mise à jour IA (secondes) >> config_ultra.mq5
echo. >> config_ultra.mq5
echo input group "=== FONCTIONNALITÉS DÉSACTIVÉES ===" >> config_ultra.mq5
echo input bool   DrawTrendlines = false;         // Désactivé pour performance >> config_ultra.mq5
echo input bool   DrawSMCZones = false;           // Désactivé pour performance >> config_ultra.mq5
echo input bool   DrawDerivPatterns = false;       // Désactivé pour performance >> config_ultra.mq5
echo input bool   DrawSupportResistance = false;    // Désactivé pour performance >> config_ultra.mq5
echo input bool   DrawAIZones = false;            // Désactivé pour performance >> config_ultra.mq5
echo input bool   ShowDashboard = false;           // Désactivé pour performance >> config_ultra.mq5
echo input bool   ShowInfoOnChart = false;        // Désactivé pour performance >> config_ultra.mq5
echo input bool   DebugMode = false;              // Désactivé pour performance >> config_ultra.mq5
echo. >> config_ultra.mq5
echo input group "=== API RÉDUITS ===" >> config_ultra.mq5
echo input bool   UseAllEndpoints = false;        // Désactiver endpoints multiples >> config_ultra.mq5
echo input bool   UseAdvancedDecisionGemma = false; // Désactiver analyse avancée >> config_ultra.mq5
echo input bool   UseTrendAPIAnalysis = false;   // Désactiver analyse tendance API >> config_ultra.mq5
echo. >> config_ultra.mq5

echo ✅ Fichier de configuration créé: config_ultra.mq5
echo.
echo 📋 INSTRUCTIONS:
echo 1. Copiez les paramètres ci-dessus dans F_INX_scalper_double.mq5
echo 2. Recompilez le robot
echo 3. Redémarrez MT5
echo.
echo 🚀 MT5 sera ultra léger et réactif!
echo.
pause
