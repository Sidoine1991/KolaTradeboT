import sys; sys.stdout.reconfigure(encoding='utf-8')

print("=== 2. ai_server Crash 500 handling (decision logic) ===", flush=True)
with open(r'D:\Dev\TradBOT\ai_server.py', encoding='utf-8', errors='ignore') as f:
    lines = f.readlines()
for i, line in enumerate(lines[1980:2030], start=1981):
    print(f"  L{i}: {line.rstrip()}", flush=True)

print("\n=== 3. ai_server symbol support list ===", flush=True)
with open(r'D:\Dev\TradBOT\ai_server.py', encoding='utf-8', errors='ignore') as f:
    for i, line in enumerate(f, 1):
        if 'SYMBOLS' in line and '=' in line and i < 500:
            print(f"  L{i}: {line.rstrip()}", flush=True)
