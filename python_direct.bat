@echo off
REM Use Python 3.14 directly (3.11 has registry corruption on CLI)
REM Daemon processes use 3.11 which works in background
C:\Python314_old\python.exe %*
