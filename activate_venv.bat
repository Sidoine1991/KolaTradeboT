@echo off
REM Script batch pour activer l'environnement virtuel .venv
REM Usage: activate_venv.bat

echo 🔍 Recherche de l'environnement virtuel...

set VENV_PATH=D:\Dev\TradBOT\.venv

REM Vérifier si le dossier .venv existe
if not exist "%VENV_PATH%" (
    echo ❌ L'environnement virtuel n'existe pas à: %VENV_PATH%
    echo 📋 Création de l'environnement virtuel...
    
    REM Créer l'environnement virtuel
    python -m venv %VENV_PATH%
    if errorlevel 1 (
        echo ❌ Erreur lors de la création de l'environnement virtuel
        echo 📋 Vérifiez que Python est installé et accessible
        pause
        exit /b 1
    )
    echo ✅ Environnement virtuel créé avec succès!
)

REM Activer l'environnement virtuel
echo 🚀 Activation de l'environnement virtuel...

set ACTIVATE_SCRIPT=%VENV_PATH%\Scripts\activate.bat

if exist "%ACTIVATE_SCRIPT%" (
    REM Exécuter le script d'activation
    call "%ACTIVATE_SCRIPT%"
    
    REM Afficher les informations
    echo ✅ Environnement virtuel activé avec succès!
    echo 📍 Chemin: %VENV_PATH%
    echo 🐍 Python:
    python --version
    echo 📦 Pip:
    pip --version
    
    REM Afficher les packages installés
    echo.
    echo 📦 Packages installés:
    pip list
    
    echo.
    echo 🎯 L'environnement est prêt!
    echo 💡 Pour désactiver: deactivate
) else (
    echo ❌ Script d'activation non trouvé: %ACTIVATE_SCRIPT%
    pause
    exit /b 1
)
