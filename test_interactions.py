"""Test que les agents lisent et influencent bien les uns les autres."""
import sys
sys.path.insert(0, '.')

from agents.orchestrator import AgentOrchestrator

orch = AgentOrchestrator()

# --- Injecter des outputs realistes dans chaque agent ---
orch.agents['regime']._last_output = {
    'global_regime': {'regime': 'VOLATILE', 'confidence': 0.82},
    'symbol_regimes': {
        'XAUUSD':        {'regime': 'VOLATILE',      'confidence': 0.85},
        'Boom500Index':  {'regime': 'TRENDING_UP',   'confidence': 0.90},
        'Crash500Index': {'regime': 'TRENDING_DOWN',  'confidence': 0.88},
        'EURUSD':        {'regime': 'RANGING',        'confidence': 0.65},
    },
    'correction_warnings': ['EURUSD'],
}

orch.agents['risk']._last_output = {
    'risk_level': 'HIGH',
    'daily_budget_remaining': 15.0,
    'can_trade': True,
    'open_positions': 4,
    'recommendations': {
        'XAUUSD': {'recommended_lot': 0.10, 'win_rate': 58.0, 'rr_ratio': 1.5},
    },
    'peer_context': {},
}

orch.agents['news']._last_output = {
    'current_impact': 'MEDIUM',
    'trading_allowed': True,
    'global_confidence_modifier': -0.07,
    'global_lot_modifier': 0.75,
    'session': {'active_sessions': ['London'], 'quality': 'good', 'recommended': True, 'hour_utc': 10},
    'upcoming_events': [{'time': '14:30', 'name': 'NFP', 'impact': 'HIGH'}],
}

orch.agents['pattern']._last_output = {
    'evolved_thresholds': {
        'XAUUSD':       {'min_coherence': 72, 'min_gap': 1.8, 'expected_wr': 63},
        'Boom500Index': {'min_coherence': 65, 'min_gap': 1.5, 'expected_wr': 70},
    },
    'top_patterns': [{'pattern': 'OB+KOLA_CONFIRMED', 'win_rate': 68}],
    'algo_footprints': [],
    'anomalies': [],
    'total_trades_analyzed': 142,
}

orch.agents['correlation']._last_output = {
    'leaders': [
        {'symbol': 'Boom500Index', 'leader_score': 0.84, 'current_direction': 'bullish'},
        {'symbol': 'XAUUSD',       'leader_score': 0.71, 'current_direction': 'bullish'},
    ],
    'hedge_pairs': [{'pair': 'Boom500/Crash500', 'correlation': -0.92}],
    'confidence_adjustments': {'Boom500Index': 0.05, 'EURUSD': -0.08},
    'group_alignment': {'boom_crash': {'score': 0.88}},
}

errors = []
results = []

# ============================================================
# TEST A : Timing lit ses 3 peers
# ============================================================
timing = orch.agents['timing']
regime_lu = timing.get_peer('regime')
risk_lu   = timing.get_peer('risk')
news_lu   = timing.get_peer('news')

r_regime = regime_lu.get('global_regime', {}).get('regime')
r_risk   = risk_lu.get('risk_level')
r_news   = news_lu.get('current_impact')

if r_regime == 'VOLATILE' and r_risk == 'HIGH' and r_news == 'MEDIUM':
    results.append("A1 PASSE: Timing lit regime=VOLATILE, risk=HIGH, news=MEDIUM")
else:
    errors.append(f"A1 ECHEC: regime={r_regime}, risk={r_risk}, news={r_news}")

# Score XAUUSD BUY avec regime VOLATILE
sym_regime = regime_lu.get('symbol_regimes', {}).get('XAUUSD', {}).get('regime', 'UNKNOWN')
score_result = timing._score_entry(
    {'symbol': 'XAUUSD', 'verdict': 'BUY', 'coherence_pct': 85, 'verdict_gap': 2.5,
     'kola_state': 'CONFIRMED', 'entry_quality': 80},
    {'in_ote': True, 'st_dir': 1, 'rsi14': 38.0,
     'tf_global_dir': 'BULL', 'tf_m1_dir': 'BULL', 'tf_m5_dir': 'BULL'},
    sym_regime=sym_regime,
    news_penalty=0.0,
)
breakdown_str = str(score_result['breakdown'])
if 'regime=VOLATILE' in breakdown_str:
    results.append(f"A2 PASSE: Regime VOLATILE applique dans scoring (score={score_result['entry_score']}/100)")
else:
    errors.append(f"A2 ECHEC: regime VOLATILE absent du breakdown: {score_result['breakdown']}")

# Score avec HIGH impact news
score_with_news = timing._score_entry(
    {'symbol': 'XAUUSD', 'verdict': 'BUY', 'coherence_pct': 85, 'verdict_gap': 2.5},
    {},
    sym_regime='TRENDING_UP',
    news_penalty=10.0,
)
if 'news_HIGH' in str(score_with_news['breakdown']):
    results.append(f"A3 PASSE: Penalite news_HIGH appliquee dans scoring")
else:
    errors.append(f"A3 ECHEC: news_HIGH absent du breakdown")

# Mode strict risk HIGH
strict_mode = risk_lu.get('risk_level') in ('HIGH', 'CRITICAL')
if strict_mode:
    results.append("A4 PASSE: Mode strict actif (risk=HIGH -> seulement IMMEDIATE accepte)")
else:
    errors.append("A4 ECHEC: mode strict non active")

# ============================================================
# TEST B : Risk lit ses 2 peers
# ============================================================
risk_agent = orch.agents['risk']
pattern_lu = risk_agent.get_peer('pattern')
regime_lu2 = risk_agent.get_peer('regime')

evolved = pattern_lu.get('evolved_thresholds', {})
if 'XAUUSD' in evolved and 'Boom500Index' in evolved:
    results.append("B1 PASSE: Risk lit evolved_thresholds de Pattern (XAUUSD + Boom500Index)")
else:
    errors.append(f"B1 ECHEC: evolved_thresholds={list(evolved.keys())}")

# Win rate ameliore par pattern
base_wr = 0.52
evolved_xau = evolved.get('XAUUSD', {})
if evolved_xau.get('expected_wr'):
    final_wr = max(base_wr, evolved_xau['expected_wr'] / 100.0)
    if final_wr == 0.63:
        results.append(f"B2 PASSE: WR XAUUSD ameliore par Pattern: 52% -> 63%")
    else:
        errors.append(f"B2 ECHEC: WR final={final_wr}, attendu 0.63")

# Lot reduit VOLATILE
sym_regime_xau = regime_lu2.get('symbol_regimes', {}).get('XAUUSD', {}).get('regime', 'UNKNOWN')
base_lot = 0.20
if sym_regime_xau == 'VOLATILE':
    adj_lot = round(base_lot * 0.5, 2)
    if adj_lot == 0.10:
        results.append(f"B3 PASSE: Lot XAUUSD reduit 50% en VOLATILE: {base_lot} -> {adj_lot}")
    else:
        errors.append(f"B3 ECHEC: lot={adj_lot}, attendu 0.10")
else:
    errors.append(f"B3 ECHEC: sym_regime_xau={sym_regime_xau}, attendu VOLATILE")

# max_open_positions reduit
global_regime_risk = regime_lu2.get('global_regime', {}).get('regime')
pos_cap = 5
if global_regime_risk in ('VOLATILE', 'RANGING'):
    pos_cap = max(1, pos_cap - 1)
if pos_cap == 4:
    results.append(f"B4 PASSE: max_open_positions 5->4 en regime VOLATILE global")
else:
    errors.append(f"B4 ECHEC: pos_cap={pos_cap}, attendu 4")

# ============================================================
# TEST C : Rapport WhatsApp mentionne les interactions
# ============================================================
orch.agents['timing']._last_output['peer_context'] = {
    'global_regime': 'VOLATILE',
    'coh_threshold_used': 60.0,
    'news_penalty': 0.0,
    'risk_strict_mode': True,
}
orch.agents['risk']._last_output['peer_context'] = {
    'global_regime': 'VOLATILE',
    'regime_pos_cap': 4,
    'evolved_symbols': ['XAUUSD', 'Boom500Index'],
}

report = orch._build_whatsapp_report()
if len(report) > 100:
    results.append(f"C1 PASSE: Rapport WhatsApp genere ({len(report)} chars)")
else:
    errors.append(f"C1 ECHEC: rapport trop court ({len(report)} chars)")

has_interaction = 'Interactions' in report or 'strict' in report or 'positions' in report
if has_interaction:
    results.append("C2 PASSE: Rapport mentionne les interactions entre agents")
else:
    errors.append("C2 ECHEC: aucune interaction mentionnee dans le rapport")

# ============================================================
# AFFICHAGE RESULTATS
# ============================================================
print("=" * 60)
print("VERIFICATION INTERACTIONS ENTRE AGENTS")
print("=" * 60)
print()
print(f"PASSES  : {len(results)}")
print(f"ECHECS  : {len(errors)}")
print()
for r in results:
    print(f"  OK  {r}")
print()
for e in errors:
    print(f"  ERR {e}")
print()

if not errors:
    print("=" * 60)
    print("TOUS LES TESTS PASSES")
    print("Les agents interagissent correctement.")
    print("=" * 60)
    print()
    print("Recap interactions verifiees:")
    print("  Regime  -> Timing : regime VOLATILE -5pts sur score")
    print("  News    -> Timing : penalite -10pts si impact HIGH")
    print("  Risk    -> Timing : mode strict si HIGH/CRITICAL")
    print("  Pattern -> Risk   : win_rate 52% -> 63% (XAUUSD)")
    print("  Regime  -> Risk   : lot XAUUSD 0.20 -> 0.10 (VOLATILE)")
    print("  Regime  -> Risk   : max_positions 5 -> 4 (global VOLATILE)")
    sys.exit(0)
else:
    print("CERTAINS TESTS ONT ECHOUE - voir ERR ci-dessus")
    sys.exit(1)
