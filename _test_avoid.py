import sys, os, datetime
sys.path.insert(0, 'D:/Dev/TradBOT/Python')
sys.path.insert(0, 'D:/Dev/TradBOT')

from symbol_mapper import resolve_mt5_symbol
from session_readiness import compute_daily_readiness, get_avoid_hours, get_best_hours

hour_utc = datetime.datetime.utcnow().hour
print('Heure UTC: %dh' % hour_utc)
print()

# Simuler ce que l'EA envoie : "Crash 500" (sans Index)
sym_raw = 'Crash 500'
sym_db  = resolve_mt5_symbol(sym_raw) or sym_raw
print('EA envoie:       %s' % sym_raw)
print('Resolu vers DB:  %s' % sym_db)
print()

avoid = get_avoid_hours(sym_db)
best  = get_best_hours(sym_db)
print('avoid_hours: %s' % avoid)
print('best_hours:  %s' % best)
print()

result = compute_daily_readiness(sym_db, hour_utc)
print('go=%s  score=%d' % (result.get('go'), result.get('score', 0)))
print('avoid_hours dans response: %s' % result.get('avoid_hours'))
print('best_hours  dans response: %s' % result.get('best_hours'))
print()

# Test gate: heure actuelle
in_avoid = hour_utc in (avoid or [])
in_best  = hour_utc in (best or [])
print('Heure %dh -> avoid=%s best=%s -> Entree: %s' % (
    hour_utc, in_avoid, in_best,
    'BLOQUEE (avoid)' if in_avoid else ('OK (best)' if in_best else 'OK (neutre)')
))

# Test avec heure avoid forcee
for h_test in [14, 21, 8, 10]:
    a = h_test in (avoid or [])
    b = h_test in (best or [])
    status = 'BLOQUEE+FERMETURE' if a else ('OK-best' if b else 'OK-neutre')
    print('  Test %02dh: avoid=%s best=%s -> %s' % (h_test, a, b, status))
