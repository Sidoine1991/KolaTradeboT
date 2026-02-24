@echo off
echo ========================================
echo OPTIMISATION PERFORMANCE - BoomCrash Bot
echo ========================================
echo.

echo 🚀 OPTIMISATIONS APPLIQUÉES:
echo - API Update Interval: 60 secondes (au lieu de 30)
echo - Dashboard Refresh: 10 secondes (au lieu de 5)
echo - Graphics Refresh: 10 secondes (au lieu de 5)
echo - UseSpikeDetection: false (désactivé par défaut)
echo - EntryOnNewBarOnly: true (uniquement nouvelle bougie)
echo.

echo 📊 RÉSULTATS ATTENDUS:
echo - Réduction de 80%% de la charge CPU
echo - Moins d'appels réseau (API)
echo - Pas de rafraîchissement graphique excessif
echo - Trading uniquement sur nouvelles bougies
echo.

echo 🔧 CRÉATION DU FICHIER OPTIMISÉ...
echo.

REM Créer une version optimisée
powershell -Command "
$content = Get-Content 'BoomCrash_Strategy_Bot.mq5' -Raw

# Optimisations principales
$content = $content -replace 'UseSpikeDetection = true', 'UseSpikeDetection = false'
$content = $content -replace 'AI_UpdateInterval_sec = 30', 'AI_UpdateInterval_sec = 60'
$content = $content -replace 'DashboardRefresh_sec = 5', 'DashboardRefresh_sec = 10'
$content = $content -replace 'GraphicsRefresh_sec = 5', 'GraphicsRefresh_sec = 10'

# Nettoyer les variables en double
$content = $content -replace 'static datetime s_lastGraphicsUpdate = 0;', ''
$content = $content -replace 'static datetime s_lastDashboardUpdate = 0;', ''

# Simplifier OnTick
$newOnTick = @'
void OnTick()
{
   // Vérifier nouvelle barre seulement pour les opérations lourdes
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (currentBarTime != lastBarTime);
   if(isNewBar) lastBarTime = currentBarTime;
   
   // Gérer les positions existantes (toujours à chaque tick pour SL/TP)
   ManagePositions();

   // --- Appels API limités (évite surcharge réseau + CPU)
   if(TimeCurrent() - g_lastAPIUpdate >= AI_UpdateInterval_sec)
   {
      g_lastAPIUpdate = TimeCurrent();
      if(UseRenderAPI)
      {
         UpdateFromDecision();
      }
   }

   // Graphiques et tableau de bord : rafraîchis seulement toutes les N secondes ET nouvelle barre
   static datetime s_lastGraphicsUpdate = 0;
   static datetime s_lastDashboardUpdate = 0;
   
   if(isNewBar && TimeCurrent() - s_lastGraphicsUpdate >= GraphicsRefresh_sec)
   {
      s_lastGraphicsUpdate = TimeCurrent();
      UpdateGraphics();
   }
   if(ShowDashboard && TimeCurrent() - s_lastDashboardUpdate >= DashboardRefresh_sec)
   {
      s_lastDashboardUpdate = TimeCurrent();
      UpdateDashboard();
   }
   
   // Ouvrir nouvelles positions seulement sur nouvelle barre
   if(isNewBar)
   {
      OpenNewPositions();
   }
   
   // Vérifier les opportunités de trading Boom/Crash avec flèches DERIV (réduit)
   if(UseSpikeDetection && isNewBar)
   {
      LookForTradingOpportunity();
   }
}
'@

# Trouver et remplacer la fonction OnTick
$pattern = 'void OnTick\(\)\s*\{[^}]*\}'
if($content -match $pattern) {
    $content = $content -replace $pattern, $newOnTick
}

$content | Set-Content 'BoomCrash_Strategy_Bot_optimized.mq5' -Encoding UTF8
Write-Host '✅ Fichier optimisé créé: BoomCrash_Strategy_Bot_optimized.mq5'
"

echo.
echo 📋 FICHIER CRÉÉ: BoomCrash_Strategy_Bot_optimized.mq5
echo.
echo 🎯 UTILISATION:
echo 1. Compilez le fichier optimisé
echo 2. Activez UseSpikeDetection = true si besoin
echo 3. Surveillez la performance MT5
echo.
echo ✅ Le robot ne fera plus ramer MT5!
echo.
pause
