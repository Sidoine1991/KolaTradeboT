@echo off
REM Kill all Python processes

title Kill Python Processes

cls

echo.
echo Killing all Python processes...
echo.

REM Kill all python.exe processes
taskkill /F /IM python.exe 2>nul

echo.
echo Waiting 2 seconds...
timeout /t 2 /nobreak

echo.
echo Verifying...
tasklist | find /I "python" >nul
if %ERRORLEVEL% EQU 0 (
    echo Still running, trying again...
    taskkill /F /IM python.exe 2>nul
    timeout /t 2 /nobreak
) else (
    echo [OK] All Python processes killed
)

echo.
echo Done!
echo.
echo Next: Double-clic START_SERVICES.bat
echo.

pause
