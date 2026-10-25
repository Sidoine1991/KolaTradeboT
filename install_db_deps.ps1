# Script PowerShell pour installer les dépendances de base de données
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "INSTALLATION DES DEPENDANCES BASE DE DONNEES" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Activer le venv si nécessaire
if (Test-Path ".venv\Scripts\Activate.ps1") {
    Write-Host "`n[1] Activation de l'environnement virtuel..." -ForegroundColor Yellow
    & .venv\Scripts\Activate.ps1
}

# Installer python-dotenv
Write-Host "`n[2] Installation de python-dotenv..." -ForegroundColor Yellow
python -m pip install python-dotenv

# Installer asyncpg
Write-Host "`n[3] Installation de asyncpg..." -ForegroundColor Yellow
python -m pip install asyncpg

# Vérifier l'installation
Write-Host "`n[4] Verification de l'installation..." -ForegroundColor Yellow
python -c "from dotenv import load_dotenv; import asyncpg; print('[OK] python-dotenv et asyncpg sont installes')"

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "INSTALLATION TERMINEE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "`n[INFO] Vous pouvez maintenant tester avec:" -ForegroundColor Cyan
Write-Host "   python test_env.py" -ForegroundColor White
Write-Host "   python check_monitoring.py" -ForegroundColor White
