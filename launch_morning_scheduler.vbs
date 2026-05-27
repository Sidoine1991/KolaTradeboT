' TradBOT Morning Scan Scheduler — Lance PowerShell silencieusement au démarrage
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ""D:\Dev\TradBOT\morning_scan_scheduler.ps1""", 0, False
