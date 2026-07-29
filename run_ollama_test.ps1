# Local non-destructive test for ollama wrappers
# 1) Lists models from models.json
# 2) Runs a harmless one-word prompt through the PowerShell wrapper
# 3) Runs the same prompt through the Python wrapper (fallback)

Write-Host "== Listing models via PS wrapper =="
.\run_ollama.ps1 -ListModels

Write-Host "`n== PS wrapper: short prompt test =="
.\run_ollama.ps1 -Prompt "Test de connexion: ok" -KeepAliveMinutes 1

Write-Host "`n== Python wrapper: list-models =="
python .\run_ollama.py --list-models

Write-Host "`n== Python wrapper: short prompt test =="
python .\run_ollama.py --prompt "Test de connexion: ok" --keepalive 1

Write-Host "`n== Test complete =="
