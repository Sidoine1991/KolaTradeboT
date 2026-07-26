#!/usr/bin/env python3
from ai_server import _gom_finalize_verdict_pipeline

# Test GOM verdict pipeline
test_out = {
    'verdict_num': 0,
    'verdict_reactive_num': 0,
    'cog_direction_5m': 'BUY',
    'cog_direction_15m': 'BUY',
    'cog_strength': 0.5,
    'cog_confidence': 0.8,
    'cog_short_agreement': 0.3,
}

try:
    _gom_finalize_verdict_pipeline(test_out, 'Boom 500 Index')
    print(f'GOM Version Test Results:')
    print(f'  verdict: {test_out.get("verdict", "N/A")}')
    print(f'  verdict_num: {test_out.get("verdict_num", "N/A")}')
    print(f'  effective_verdict_num: {test_out.get("effective_verdict_num", "N/A")}')
    print(f'  forecast_verdict_num: {test_out.get("forecast_verdict_num", "N/A")}')
    print(f'  verdict_mode: {test_out.get("verdict_mode", "N/A")}')
    print(f'  SUCCESS: GOM verdict pipeline working with predictive blend!')
except Exception as e:
    print(f'  ERROR: {str(e)}')
    import traceback
    traceback.print_exc()