@echo off
echo Démarrage du client IA MT5...
echo Recherche de l'environnement Python avec modules...

REM Tester Python 3.13 (Windows Store)
"C:\Users\USER\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\LocalCache\local-packages\python313\python.exe" -c "import requests; print('Python 3.13 OK')" 2>nul
if %errorlevel% == 0 (
    echo Utilisation de Python 3.13 avec modules
    "C:\Users\USER\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\LocalCache\local-packages\python313\python.exe" mt5_ai_client.py
    goto end
)

REM Tester Python 3.11
"C:\Users\USER\AppData\Local\Programs\Python\Python311\python.exe" -c "import requests; print('Python 3.11 OK')" 2>nul
if %errorlevel% == 0 (
    echo Utilisation de Python 3.11
    "C:\Users\USER\AppData\Local\Programs\Python\Python311\python.exe" mt5_ai_client.py
    goto end
)

echo Aucun environnement Python avec modules trouvé
echo Installation des modules nécessaires...
python -m pip install requests MetaTrader5 numpy pandas
python mt5_ai_client.py

:end
pause
