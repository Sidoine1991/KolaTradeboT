import sys
sys.stdout.reconfigure(line_buffering=True)
sys.path.insert(0, 'D:/Dev/TradBOT/python')
import perfect_opportunity_scanner as s

# Fast symbols only (skip slow forex)
symbols = ["XAUUSD", "Boom500", "Crash500", "Boom1000", "Crash1000",
            "BTCUSD", "ETHUSD"]

print("[TEST] Starting scan...", flush=True)
perfect = s.scan_perfect_opportunities(symbols)
print(f"[TEST] Found {len(perfect)} perfect", flush=True)
for p in perfect:
    print(f"  {p.get('symbol')} {p.get('action')} IA={p.get('ia_confidence')} GOM={p.get('gom_coherence')} PROB={p.get('probability')}", flush=True)

if perfect:
    s.update_api_opportunities(perfect)
    print("[TEST] Pushed to API", flush=True)

print("[TEST] Done", flush=True)
