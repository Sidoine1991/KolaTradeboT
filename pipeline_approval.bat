@echo off
cd /d "D:\Dev\TradBOT"
set PYTHONHTTPSVERIFY=0
set REQUESTS_CA_BUNDLE=
set SSL_CERT_FILE=
set CURL_CA_BUNDLE=
set HTTPX_VERIFY=0
"D:\Dev\Depot Github\TradingAgents-main\.venv\Scripts\python.exe" Python\pipeline_with_approval.py %*
