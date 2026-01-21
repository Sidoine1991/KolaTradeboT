# Script PowerShell pour démarrer le serveur avec le venv activé
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "DEMARRAGE DU SERVEUR AI TRADBOT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Vérifier que le venv existe
if (-not (Test-Path ".venv\Scripts\python.exe")) {
    Write-Host "[ERREUR] Environnement virtuel non trouve!" -ForegroundColor Red
    Write-Host "[INFO] Creez-le avec: python -m venv .venv" -ForegroundColor Yellow
    exit 1
}

# Activer le venv
Write-Host "`n[1] Activation de l'environnement virtuel..." -ForegroundColor Yellow
& .venv\Scripts\Activate.ps1

# Vérifier les dépendances
Write-Host "`n[2] Verification des dependances..." -ForegroundColor Yellow
try {
    .venv\Scripts\python.exe -c "from dotenv import load_dotenv; import asyncpg; print('[OK] Dependances OK')"
} catch {
    Write-Host "[ERREUR] Dependances manquantes!" -ForegroundColor Red
    Write-Host "[INFO] Installez avec: .venv\Scripts\python.exe -m pip install python-dotenv asyncpg" -ForegroundColor Yellow
    exit 1
}

# Vérifier le fichier .env
Write-Host "`n[3] Verification du fichier .env..." -ForegroundColor Yellow
if (Test-Path ".env") {
    Write-Host "[OK] Fichier .env trouve" -ForegroundColor Green
    .venv\Scripts\python.exe -c "import os; from dotenv import load_dotenv; load_dotenv(); print('[OK] DATABASE_URL:', 'defini' if os.getenv('DATABASE_URL') else 'NON DEFINI')"
} else {
    Write-Host "[WARN] Fichier .env non trouve" -ForegroundColor Yellow
}

# Démarrer le serveur
Write-Host "`n[4] Demarrage du serveur..." -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Serveur accessible sur: http://localhost:8000" -ForegroundColor Green
Write-Host "Documentation: http://localhost:8000/docs" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Démarrer avec le Python du venv
.venv\Scripts\python.exe ai_server.py
