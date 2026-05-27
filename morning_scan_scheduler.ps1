# ═══════════════════════════════════════════════════════════════
# TradBOT Morning Scan Scheduler — sans droits admin
# Ce script tourne en arrière-plan et lance morning_scan.bat
# chaque jour de semaine à 07h03 UTC (09h03 heure locale UTC+2)
# ═══════════════════════════════════════════════════════════════

$LogFile = "D:\Dev\TradBOT\logs\scheduler.log"
$ScanBat = "D:\Dev\TradBOT\morning_scan.bat"

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts $msg" | Add-Content $LogFile
    Write-Host "$ts $msg"
}

Write-Log "=== TradBOT Morning Scan Scheduler démarré ==="

while ($true) {
    $now   = Get-Date
    $dow   = $now.DayOfWeek.value__   # 0=Dim, 1=Lun, 5=Ven, 6=Sam
    $isWeekday = $dow -ge 1 -and $dow -le 5

    # Heure cible locale : 09h03 (= 07h03 UTC en été)
    $target = [DateTime]::new($now.Year, $now.Month, $now.Day, 9, 3, 0)

    # Si on a passé l'heure aujourd'hui, viser demain
    if ($now -ge $target) {
        $target = $target.AddDays(1)
        # Sauter le weekend
        while ($target.DayOfWeek -eq 'Saturday' -or $target.DayOfWeek -eq 'Sunday') {
            $target = $target.AddDays(1)
        }
    }

    $waitSec = [int]($target - $now).TotalSeconds
    Write-Log "Prochain scan : $($target.ToString('yyyy-MM-dd HH:mm')) — dans $([int]($waitSec/3600))h$([int](($waitSec%3600)/60))m"

    # Attendre jusqu'au prochain déclenchement (vérification toutes les 60s)
    $elapsed = 0
    while ($elapsed -lt $waitSec) {
        Start-Sleep -Seconds 60
        $elapsed += 60
        # Vérifier si l'heure est arrivée
        $nowCheck = Get-Date
        if ($nowCheck -ge $target) { break }
    }

    # Vérifier que c'est bien un jour de semaine
    $fireDay = (Get-Date).DayOfWeek
    if ($fireDay -ne 'Saturday' -and $fireDay -ne 'Sunday') {
        Write-Log "LANCEMENT Morning Scan..."
        try {
            $proc = Start-Process -FilePath "cmd.exe" `
                -ArgumentList "/c `"$ScanBat`"" `
                -WorkingDirectory "D:\Dev\TradBOT" `
                -PassThru -Wait
            Write-Log "Morning Scan terminé (exit code: $($proc.ExitCode))"
        } catch {
            Write-Log "ERREUR Morning Scan: $_"
        }
    } else {
        Write-Log "Weekend détecté ($fireDay) — scan ignoré"
    }
}
