@echo off
echo ========================================
echo    TRADBOT - APPLICATION TEMPS REEL
echo ========================================
echo.
echo Lancement de l'application...
echo.

cd /d "%~dp0frontend"

echo Vérification de Python...
python --version
if errorlevel 1 (
    echo ❌ Python n'est pas installé ou n'est pas dans le PATH
    pause
    exit /b 1
)

echo.
echo Vérification de Streamlit...
python -c "import streamlit; print('✅ Streamlit version:', streamlit.__version__)"
if errorlevel 1 (
    echo ❌ Streamlit n'est pas installé. Installation en cours...
    python -m pip install streamlit
)

echo.
echo 🚀 Lancement de l'application temps réel...
echo 📱 L'application s'ouvrira dans votre navigateur
echo 🌐 Adresse: http://localhost:8501
echo.

python -m streamlit run app_real_time.py

pause 