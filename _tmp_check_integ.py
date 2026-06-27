import sys; sys.stdout.reconfigure(encoding='utf-8')

# 1. Verify ai_server can handle Crash 500 symbol
print("=== 1. ai_server symbol mapping ===", flush=True)
with open(r'D:\Dev\TradBOT\ai_server.py', encoding='utf-8', errors='ignore') as f:
    for i, line in enumerate(f, 1):
        if 'Crash' in line and i < 5000:
            print(f"  L{i}: {line.rstrip()}", flush=True)
