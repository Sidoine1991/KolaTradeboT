@echo off
echo ========================================
echo FIX DEPENDENCIES - TradBOT AI Server
echo ========================================
echo.

echo [1/5] Verification Python...
python --version
if errorlevel 1 (
    echo ERREUR: Python non trouve!
    pause
    exit /b 1
)
echo ✅ Python OK
echo.

echo [2/5] Mise a jour pip...
python -m pip install --upgrade pip
echo ✅ pip mis a jour
echo.

echo [3/5] Reinstallation pandas (fix C extension)...
python -m pip uninstall -y pandas
python -m pip install pandas --no-cache-dir
echo ✅ pandas reinstalle
echo.

echo [4/5] Installation dependances manquantes...
python -m pip install fastapi uvicorn pydantic numpy requests joblib scikit-learn --upgrade
echo ✅ Dependances installees
echo.

echo [5/5] Test final...
python -c "import fastapi, uvicorn, pandas, numpy, sklearn; print('✅ Toutes les dependances sont OK!')"
if errorlevel 1 (
    echo ⚠️  Erreur lors du test
    pause
    exit /b 1
)
echo.

echo ========================================
echo ✅ DEPENDANCES REPAREES AVEC SUCCES!
echo ========================================
echo.
echo Vous pouvez maintenant lancer:
echo   python ai_server.py
echo.
pause
