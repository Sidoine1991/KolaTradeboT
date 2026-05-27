# ═══════════════════════════════════════════════════════════════
# TradBOT — Installation Windows Task Scheduler
# Morning Market Scanner à 07h00 UTC (09h00 heure locale UTC+2)
# Lancer en tant qu'administrateur : powershell -ExecutionPolicy Bypass -File install_morning_scan_task.ps1
# ═══════════════════════════════════════════════════════════════

$TaskName    = "TradBOT_MorningScan"
$ScriptPath  = "D:\Dev\TradBOT\morning_scan.bat"
$LogDir      = "D:\Dev\TradBOT\logs"

# Créer le dossier logs si absent
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

# Supprimer la tâche existante si elle existe
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "[OK] Ancienne tâche supprimée"
}

# Définir le déclencheur : lundi–vendredi à 09h00 heure locale (= 07h00 UTC en été)
$Trigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek Monday, Tuesday, Wednesday, Thursday, Friday `
    -At "09:03AM"

# Action : lancer morning_scan.bat
$Action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"$ScriptPath`"" `
    -WorkingDirectory "D:\Dev\TradBOT"

# Paramètres : lancer même si non connecté, priorité normale
$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -WakeToRun

# Enregistrer la tâche (compte utilisateur actuel)
$Principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $TaskName `
    -Trigger $Trigger `
    -Action $Action `
    -Settings $Settings `
    -Principal $Principal `
    -Description "TradBOT Morning Market Scanner — SMC/ICT scan Forex+Or via MCP TradingView" `
    -Force

Write-Host ""
Write-Host "═══════════════════════════════════════════════════"
Write-Host " TradBOT Morning Scan — Tâche planifiée installée"
Write-Host "═══════════════════════════════════════════════════"
Write-Host " Nom      : $TaskName"
Write-Host " Script   : $ScriptPath"
Write-Host " Horaire  : Lun-Ven à 09h03 heure locale (07h03 UTC)"
Write-Host " Logs     : $LogDir\morning_scan.log"
Write-Host "═══════════════════════════════════════════════════"
Write-Host ""
Write-Host "Pour vérifier : Get-ScheduledTask -TaskName '$TaskName'"
Write-Host "Pour tester   : Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "Pour supprimer: Unregister-ScheduledTask -TaskName '$TaskName'"
