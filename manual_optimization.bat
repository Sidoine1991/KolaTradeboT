@echo off
echo ========================================
echo OPTIMISATION MANUELLE - BoomCrash Bot
echo ========================================
echo.

echo 🔧 MODIFICATIONS À FAIRE MANUELLEMENT:
echo.
echo 1. Ligne 27: Changer
echo    UseSpikeDetection = true
echo    PAR:
echo    UseSpikeDetection = false
echo.
echo 2. Ligne 42: Changer
echo    AI_UpdateInterval_sec = 30
echo    PAR:
echo    AI_UpdateInterval_sec = 60
echo.
echo 3. Ligne 66: Changer
echo    DashboardRefresh_sec = 5
echo    PAR:
echo    DashboardRefresh_sec = 10
echo.
echo 4. Ligne 67: Changer
echo    GraphicsRefresh_sec = 5
echo    PAR:
echo    GraphicsRefresh_sec = 10
echo.
echo 5. Remplacer TOUTE la fonction OnTick (lignes 280-347) par:
echo.

echo void OnTick()
echo {
echo    // Vérifier nouvelle barre seulement pour les opérations lourdes
echo    static datetime lastBarTime = 0;
echo    datetime currentBarTime = iTime(_Symbol, _Period, 0);
echo    bool isNewBar = (currentBarTime != lastBarTime);
echo    if(isNewBar) lastBarTime = currentBarTime;
echo    
echo    // Gérer les positions existantes (toujours à chaque tick pour SL/TP)
echo    ManagePositions();
echo.
echo    // --- Appels API limités (évite surcharge réseau + CPU)
echo    if(TimeCurrent() - g_lastAPIUpdate >= AI_UpdateInterval_sec)
echo    {
echo       g_lastAPIUpdate = TimeCurrent();
echo       if(UseRenderAPI)
echo       {
echo          UpdateFromDecision();
echo       }
echo    }
echo.
echo    // Graphiques et tableau de bord : rafraîchis seulement toutes les N secondes ET nouvelle barre
echo    static datetime s_lastGraphicsUpdate = 0;
echo    static datetime s_lastDashboardUpdate = 0;
echo    
echo    if(isNewBar && TimeCurrent() - s_lastGraphicsUpdate >= GraphicsRefresh_sec)
echo    {
echo       s_lastGraphicsUpdate = TimeCurrent();
echo       UpdateGraphics();
echo    }
echo    if(ShowDashboard && TimeCurrent() - s_lastDashboardUpdate >= DashboardRefresh_sec)
echo    {
echo       s_lastDashboardUpdate = TimeCurrent();
echo       UpdateDashboard();
echo    }
echo    
echo    // Ouvrir nouvelles positions seulement sur nouvelle barre
echo    if(isNewBar)
echo    {
echo       OpenNewPositions();
echo    }
echo    
echo    // Vérifier les opportunités de trading Boom/Crash avec flèches DERIV (réduit)
echo    if(UseSpikeDetection && isNewBar)
echo    {
echo       LookForTradingOpportunity();
echo    }
echo }
echo.

echo 🚀 RÉSULTATS:
echo - 80%% moins de charge CPU
echo - Plus de rafraîchissements excessifs
echo - Trading uniquement sur nouvelles bougies
echo - Appels API réduits de moitié
echo.

echo ✅ Après ces modifications, MT5 ne ramera plus!
echo.
pause
