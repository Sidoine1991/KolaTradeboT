# Quick launcher for GOM Sync 10-minute setup
# Usage: .\launch-gom-10min.ps1 [install|verify|test|run|help]

param(
    [ValidateSet('install', 'verify', 'test', 'run', 'help', 'logs', 'fix')]
    [string]$Command = 'help'
)

$ProjectRoot = "D:\Dev\TradBOT"

function Show-Help {
    Write-Host @"
╔════════════════════════════════════════════════════════════╗
║  GOM SYNC 10-MINUTE LAUNCHER                               ║
╚════════════════════════════════════════════════════════════╝

Usage: .\launch-gom-10min.ps1 [command]

Commands:
  install    Install scheduled task (requires admin)
  verify     Check task status and configuration
  test       Run pre-flight tests
  run        Execute one GOM sync immediately
  fix        Auto-fix task issues
  logs       View recent log entries
  help       Show this help message

Examples:
  .\launch-gom-10min.ps1 install    # Setup Task Scheduler
  .\launch-gom-10min.ps1 verify     # Check installation
  .\launch-gom-10min.ps1 run        # Execute immediately
  .\launch-gom-10min.ps1 logs       # Monitor activity

Documentation:
  README_GOM_SYNC_10MIN.md     Complete reference guide
  GOM_SYNC_SETUP.md            Setup instructions

Status: ✅ Production Ready (pending admin install)
"@
}

function Invoke-Install {
    Write-Host "`n[INSTALL] GOM Sync 10-Minute Task"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check admin
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "❌ ERROR: Administrator privileges required"
        Write-Host ""
        Write-Host "Please:"
        Write-Host "  1. Right-click PowerShell"
        Write-Host "  2. Select 'Run as administrator'"
        Write-Host "  3. Navigate to project: cd $ProjectRoot"
        Write-Host "  4. Run again: .\launch-gom-10min.ps1 install"
        return
    }

    Write-Host "✅ Running with admin privileges`n"

    # Check Python
    $pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $pythonPath) {
        Write-Host "❌ Python not found in PATH"
        Write-Host "   Please install Python 3.11+ or add to PATH"
        return
    }
    Write-Host "✅ Python found: $pythonPath"

    # Run bat installer
    $batPath = "$ProjectRoot\install-gom-task.bat"
    if (Test-Path $batPath) {
        Write-Host "✅ Calling installer: $batPath`n"
        & $batPath
    } else {
        Write-Host "❌ Installer not found: $batPath"
    }
}

function Invoke-Verify {
    Write-Host "`n[VERIFY] GOM Sync Task Status"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    $psPath = "$ProjectRoot\verify-gom-task.ps1"
    if (Test-Path $psPath) {
        & $psPath
    } else {
        Write-Host "❌ Verifier not found: $psPath"
    }
}

function Invoke-Test {
    Write-Host "`n[TEST] Pre-flight Checks"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    $batPath = "$ProjectRoot\test-gom-setup.bat"
    if (Test-Path $batPath) {
        Write-Host "✅ Running test script: $batPath`n"
        & cmd /c $batPath
    } else {
        Write-Host "❌ Test script not found: $batPath"
    }
}

function Invoke-Run {
    Write-Host "`n[RUN] Execute GOM Sync (One-Shot)"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    $scriptPath = "$ProjectRoot\Python\gom_sync_with_report.py"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "❌ Script not found: $scriptPath"
        return
    }

    $pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $pythonPath) {
        Write-Host "❌ Python not found in PATH"
        return
    }

    Write-Host "✅ Python: $pythonPath"
    Write-Host "✅ Script: $scriptPath"
    Write-Host "`nExecuting...`n"

    Push-Location $ProjectRoot
    & $pythonPath $scriptPath --report
    Pop-Location

    Write-Host "`n✅ Execution complete"
    Write-Host "Check logs: tail -20 logs/gom_sync.log"
}

function Invoke-Fix {
    Write-Host "`n[FIX] Auto-correct Task Issues"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    $psPath = "$ProjectRoot\verify-gom-task.ps1"
    if (Test-Path $psPath) {
        & $psPath -Fix
    } else {
        Write-Host "❌ Verifier not found: $psPath"
    }
}

function Invoke-Logs {
    Write-Host "`n[LOGS] Recent Activity"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    $logPath = "$ProjectRoot\logs\gom_sync.log"
    if (Test-Path $logPath) {
        Write-Host "`nLast 20 entries:`n"
        Get-Content $logPath -Tail 20 | ForEach-Object {
            if ($_ -match "\[ERROR\]") {
                Write-Host "❌ $_" -ForegroundColor Red
            } elseif ($_ -match "✅") {
                Write-Host "✅ $_" -ForegroundColor Green
            } elseif ($_ -match "\[GATE") {
                Write-Host "⚠️  $_" -ForegroundColor Yellow
            } else {
                Write-Host $_
            }
        }
    } else {
        Write-Host "⚠️ Log file not found yet: $logPath"
        Write-Host "Will be created on first execution"
    }
}

# Route command
switch ($Command) {
    'install' { Invoke-Install }
    'verify'  { Invoke-Verify }
    'test'    { Invoke-Test }
    'run'     { Invoke-Run }
    'fix'     { Invoke-Fix }
    'logs'    { Invoke-Logs }
    default   { Show-Help }
}

Write-Host ""
