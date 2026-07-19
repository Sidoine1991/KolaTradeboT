@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\free-claude-code\scripts\Start-ClaudeCode.ps1" %*
