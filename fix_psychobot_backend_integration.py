"""
Fix PsychoBot Frontend ↔ Backend Data Integration
The frontend is showing mocked data instead of real backend data
"""

import sys
from pathlib import Path

_root = Path(__file__).resolve().parent
sys.path.insert(0, str(_root))

print("\n" + "="*70)
print("PSYCHOBOT BACKEND DATA INTEGRATION FIX")
print("="*70)

print("\n[PROBLEM] Frontend showing mocked data instead of backend data")
print("[CAUSE] API endpoints not being called from frontend")
print("[SOLUTION] Configure frontend to fetch from backend API")

print("\n" + "="*70)
print("STEP 1: Check Backend API Endpoints")
print("="*70)

backend_endpoints = {
    "Career-Ops Status": "GET /api/career-ops/status",
    "Career-Ops Help": "GET /api/career-ops/help",
    "Career-Ops Commands": "GET /api/career-ops/commands",
    "Test Command": "POST /api/career-ops/test-command",
    "Send Message": "POST /api/career-ops/send-message",
    "Incoming Webhook": "POST /api/career-ops/webhook/incoming-message"
}

print("\nAvailable Career-Ops Endpoints:")
for name, endpoint in backend_endpoints.items():
    print(f"  [OK] {endpoint:<45} ({name})")

print("\n" + "="*70)
print("STEP 2: Frontend API Configuration")
print("="*70)

frontend_config = """
// In your PsychoBot frontend (React/Vue/etc):

const API_BASE = "http://localhost:8000/api"  // or your server URL

// Example: Fetch commands from backend
async function loadCareerOpsCommands() {
  try {
    const response = await fetch(`${API_BASE}/career-ops/commands`)
    const data = await response.json()
    // Use data.commands instead of hardcoded mock
    setCommands(data.commands)
  } catch (error) {
    console.error("Failed to load commands", error)
    // Fallback to mock if backend unavailable
  }
}

// Example: Fetch job matches
async function loadJobMatches() {
  try {
    const response = await fetch(`${API_BASE}/career-ops/jobs`)
    const data = await response.json()
    setJobs(data.jobs)
  } catch (error) {
    console.error("Failed to load jobs", error)
  }
}

// Example: Send message and get Career-Ops response
async function sendCareerOpsMessage(message) {
  try {
    const response = await fetch(`${API_BASE}/career-ops/test-command`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: message })
    })
    const data = await response.json()
    return data.response  // Real response from backend!
  } catch (error) {
    console.error("Failed to send message", error)
  }
}
"""

print(frontend_config)

print("\n" + "="*70)
print("STEP 3: Verify Backend is Running")
print("="*70)

import requests
import time

try:
    # Check if ai_server is running
    response = requests.get("http://localhost:8000/api/career-ops/status", timeout=5)
    if response.status_code == 200:
        data = response.json()
        print("\n[OK] Backend is RUNNING and responding!")
        print(f"  Status: {data.get('status')}")
        print(f"  Database: {data.get('database')}")
        print(f"  Commands: {data.get('commands')}")
    else:
        print(f"\n[ERROR] Backend returned status: {response.status_code}")

except requests.exceptions.ConnectionError:
    print("\n[ERROR] Cannot connect to localhost:8000")
    print("  ACTION REQUIRED:")
    print("  1. Start ai_server.py: python ai_server.py")
    print("  2. Wait 5 seconds for server to start")
    print("  3. Then run this script again")

except Exception as e:
    print(f"\n[ERROR] Error connecting: {str(e)}")

print("\n" + "="*70)
print("STEP 4: Frontend URL Configuration")
print("="*70)

print("\nMake sure your frontend is configured to use:")
print("  Development: http://localhost:8000/api")
print("  Production: https://your-server.com/api")

print("\nDO NOT hardcode mock data in your frontend!")
print("ALWAYS fetch from backend endpoints")

print("\n" + "="*70)
print("STEP 5: CORS Configuration (if needed)")
print("="*70)

print("\nIf frontend is on different domain, check CORS in ai_server.py:")
print("""
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # or specific domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
""")

print("\n" + "="*70)
print("STEP 6: Test Each Endpoint")
print("="*70)

print("\nRun these curl commands to test:")

test_commands = {
    "Get Status": 'curl http://localhost:8000/api/career-ops/status',
    "Get Commands": 'curl http://localhost:8000/api/career-ops/commands',
    "Get Help": 'curl http://localhost:8000/api/career-ops/help',
    "Test Command": 'curl -X POST http://localhost:8000/api/career-ops/test-command -H "Content-Type: application/json" -d \'{"message": "show me best jobs"}\'',
}

for name, cmd in test_commands.items():
    print(f"\n  {name}:")
    print(f"  {cmd}")

print("\n" + "="*70)
print("QUICK CHECKLIST")
print("="*70)

checklist = [
    "Backend (ai_server.py) is running",
    "Career-Ops router is added to ai_server.py",
    "Frontend is calling /api/career-ops/* endpoints",
    "Frontend is NOT using hardcoded mock data",
    "CORS is properly configured",
    "Both backend and frontend are on same network/server",
]

for i, item in enumerate(checklist, 1):
    print(f"  [_] {i}. {item}")

print("\n" + "="*70)
print("COMMON ISSUES & FIXES")
print("="*70)

issues = {
    "Still seeing mock data": [
        "1. Check browser DevTools → Network tab",
        "2. Look for /api/career-ops/* requests",
        "3. If no requests: frontend not calling backend",
        "4. Add console.log to verify API calls"
    ],
    "CORS error": [
        "1. Ensure CORSMiddleware is added to FastAPI",
        "2. Check allow_origins includes frontend domain",
        "3. Restart ai_server.py after CORS changes"
    ],
    "Connection refused": [
        "1. Verify ai_server.py is running",
        "2. Check if running on port 8000",
        "3. Try: python ai_server.py --reload"
    ],
    "404 Not Found": [
        "1. Verify routes are registered with app.include_router()",
        "2. Check prefix matches (/api/career-ops/*)",
        "3. Restart server and try again"
    ]
}

for issue, fixes in issues.items():
    print(f"\n{issue}:")
    for fix in fixes:
        print(f"  {fix}")

print("\n" + "="*70)
print("NEXT STEPS")
print("="*70)

print("""
1. START ai_server.py if not running:
   python ai_server.py

2. VERIFY backend is responding:
   curl http://localhost:8000/api/career-ops/status

3. UPDATE your PsychoBot frontend to:
   - Remove hardcoded mock data
   - Add API calls to /api/career-ops/* endpoints
   - Handle loading states and errors

4. TEST frontend with real backend data:
   - Open PsychoBot interface
   - Send /help command
   - Should show real commands from backend
   - Commands should work with real Career-Ops data

5. CONFIGURE daily scheduler:
   - Run: setup_careerops_automation.ps1
   - Verify task appears in Windows Task Scheduler
   - Check tomorrow at 06:00 WAT for first report
""")

print("="*70)
print("HELP NEEDED?")
print("="*70)

print("\nReply with what you see:")
print("  1. Is ai_server.py running? (check console)")
print("  2. What data is PsychoBot frontend showing? (mock or real?)")
print("  3. Any errors in browser console? (DevTools → Console tab)")
print("  4. Can you curl the /api/career-ops/status endpoint?")

print("\n")
