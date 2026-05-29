# Setup XAUUSD 20-min WhatsApp Monitor

Complete setup guide for autonomous XAUUSD surveillance system.

## Prerequisites

✅ **Required**
- Python 3.8+ installed
- TradBOT project folder: `D:\Dev\TradBOT\`
- AI Server running: `http://127.0.0.1:8000`
- PsychoBot accessible: `https://psychobot-1si7.onrender.com`
- TradingView Desktop with MCP enabled

✅ **Optional but Recommended**
- Claude Code CLI installed (for MCP integration)

## Step 1: Install Dependencies

### Windows (PowerShell)

```powershell
# Open PowerShell as Administrator
cd D:\Dev\TradBOT

# Install httpx
python -m pip install httpx -q

# Verify
python -c "import httpx; print('✅ Ready')"
```

### Linux/macOS (Bash)

```bash
cd D:/Dev/TradBOT
python3 -m pip install httpx -q
python3 -c "import httpx; print('✅ Ready')"
```

## Step 2: Test Connections

### Windows

```powershell
python run_xauusd_monitor.py --test
```

Expected output:
```
[...] ℹ️  Testing connections...
[...] ℹ️  Testing AI Server...
[...] ✅ AI Server OK: session-bias returned {...}
[...] ℹ️  Testing PsychoBot...
[...] ✅ PsychoBot OK: test message sent
[...] 📊 Connection tests complete
```

### Linux/macOS

```bash
python3 run_xauusd_monitor.py --test
```

## Step 3: Run Test Alert

Send one test alert to verify everything works:

### Windows

```powershell
python run_xauusd_monitor.py --once
```

### Linux/macOS

```bash
python3 run_xauusd_monitor.py --once
```

Check WhatsApp for incoming message. If received ✅, continue to Step 4.

## Step 4: Start Continuous Monitoring

### Option A: Windows PowerShell (Recommended)

```powershell
# Start in background
Start-Process powershell -ArgumentList `
  "-NoExit -Command python D:\Dev\TradBOT\run_xauusd_monitor.py" `
  -WindowStyle Minimized
```

Or use the provided starter script:

```powershell
powershell -ExecutionPolicy Bypass -File D:\Dev\TradBOT\Start-XAUUSDMonitor.ps1
```

### Option B: Windows Command Prompt

```cmd
cd D:\Dev\TradBOT
start python run_xauusd_monitor.py
```

### Option C: Linux/macOS (Background)

```bash
nohup python3 run_xauusd_monitor.py > xauusd_monitor.log 2>&1 &
echo $! > .xauusd_monitor.pid
```

### Option D: Linux/macOS (Screen/Tmux)

```bash
# Using screen
screen -S xauusd -d -m python3 run_xauusd_monitor.py

# Using tmux
tmux new-session -d -s xauusd -c D:/Dev/TradBOT "python3 run_xauusd_monitor.py"
```

## Verification

### Check Monitor is Running

**Windows (PowerShell)**
```powershell
Get-Process python | Where-Object {$_.CommandLine -match "run_xauusd_monitor"}
```

**Linux/macOS**
```bash
ps aux | grep run_xauusd_monitor | grep -v grep
```

### View Live Logs

**Windows (PowerShell)**
```powershell
Get-Content D:\Dev\TradBOT\xauusd_monitor.log -Tail 20 -Wait
```

**Linux/macOS**
```bash
tail -f D:/Dev/TradBOT/xauusd_monitor.log
```

### Monitor WhatsApp Alerts

You should receive WhatsApp alerts every 20 minutes.

First alert: Within 1 minute of starting
Subsequent alerts: Every 20 minutes on schedule

## Troubleshooting

### "Python not found" or "Python 3 not found"

**Windows**
```powershell
# Check if Python is installed
python --version

# If not found, download from https://www.python.org/downloads/
# Make sure to check "Add Python to PATH" during installation
```

**Linux/macOS**
```bash
# macOS with Homebrew
brew install python3

# Ubuntu/Debian
sudo apt-get install python3
```

### "httpx module not found"

```bash
# Windows
python -m pip install httpx

# Linux/macOS
python3 -m pip install httpx
```

### "Connection refused: http://127.0.0.1:8000"

1. Check if AI Server is running:
   ```bash
   curl http://127.0.0.1:8000/health
   ```

2. Start AI Server if needed

3. Monitor will continue with available data

### "WhatsApp message not arriving"

1. Check PsychoBot is online:
   ```bash
   curl https://psychobot-1si7.onrender.com/send-message
   ```

2. Verify phone number format: `+COUNTRY_CODE_PHONE`

3. Check alert fallback log:
   ```bash
   cat D:/Dev/TradBOT/whatsapp_alerts.log | tail -20
   ```

### Monitor Using 100% CPU

This shouldn't happen. Monitor sleeps 20 minutes between checks.

1. Stop monitor
2. Check logs for errors
3. Restart

### Monitor Crashes Silently

1. Check monitor.log for errors:
   ```bash
   tail -n 50 D:/Dev/TradBOT/xauusd_monitor.log
   ```

2. Run with verbose output:
   ```bash
   python3 run_xauusd_monitor.py 2>&1
   ```

3. Report error with log excerpt

## Advanced Configuration

### Custom Check Interval

Edit `run_xauusd_monitor.py`:

```python
CHECK_INTERVAL = 10 * 60  # 10 minutes
```

### Custom Phone Number

```bash
# Windows
$env:WHATSAPP_PHONE = "+1234567890"
python run_xauusd_monitor.py

# Linux/macOS
export WHATSAPP_PHONE="+1234567890"
python3 run_xauusd_monitor.py
```

### Custom AI Server URL

```bash
# Windows
$env:AI_SERVER_URL = "http://custom-server:8000"
python run_xauusd_monitor.py

# Linux/macOS
export AI_SERVER_URL="http://custom-server:8000"
python3 run_xauusd_monitor.py
```

## Stopping the Monitor

### Windows

```powershell
# List python processes
Get-Process python

# Stop specific process
Stop-Process -Id <PID>

# Or close the window manually
```

### Linux/macOS

```bash
# Kill by PID
kill $(cat .xauusd_monitor.pid)

# Or list and kill by PID
ps aux | grep run_xauusd_monitor
kill <PID>
```

## Integration with Existing Systems

The monitor integrates with:

- **AI Server** — Fetches session bias, pending orders, report status every 20 minutes
- **PsychoBot** — Sends WhatsApp alerts via `/send-message` endpoint
- **TradingView MCP** — Can be extended to fetch real-time quotes and indicators
- **EA (MT5)** — Reads pending order status from AI server

## Files

| File | Purpose |
|------|---------|
| `run_xauusd_monitor.py` | Main monitor script (all-in-one) |
| `xauusd_monitor.py` | Simplified version |
| `xauusd_monitor_config.json` | Configuration schema |
| `XAUUSD_MONITOR.md` | Detailed documentation |
| `Start-XAUUSDMonitor.ps1` | Windows starter script |
| `start_xauusd_monitor.sh` | Linux starter script |
| `xauusd_monitor.log` | Monitor operation log |
| `whatsapp_alerts.log` | WhatsApp fallback log |

## Support

If monitor doesn't work:

1. Run `--test` to check connections
2. Run `--once` to test single cycle
3. Check logs: `xauusd_monitor.log`
4. Verify AI server is running: `curl http://127.0.0.1:8000/session-bias?symbol=XAUUSD`
5. Verify PsychoBot is reachable: `curl https://psychobot-1si7.onrender.com`

## Success Criteria

✅ Monitor started without errors
✅ First test alert received on WhatsApp within 1 minute
✅ Alerts continue every 20 minutes
✅ Monitor.log shows no errors
✅ Can be stopped and restarted without issues

## Next: TradingView MCP Integration

To enhance monitoring with real-time TradingView data:

1. Use `scripts/xauusd_monitor_mcp.py` for full MCP integration
2. Or manually call MCP functions in Claude Code to fetch:
   - XAUUSD live price
   - RSI, VWAP, Bollinger Bands
   - GOM KOLA verdict from Pine tables

This is optional — monitor works with AI server data alone.
