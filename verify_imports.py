#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verify that all imports and functions are available"""

import sys
import io

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

print("Checking imports and functions...\n")

try:
    import pandas as pd
    print("✓ pandas available")
except ImportError as e:
    print(f"✗ pandas missing: {e}")
    sys.exit(1)

try:
    import requests
    print("✓ requests available")
except ImportError as e:
    print(f"✗ requests missing: {e}")
    sys.exit(1)

try:
    from datetime import datetime
    print("✓ datetime available")
except ImportError as e:
    print(f"✗ datetime missing: {e}")
    sys.exit(1)

# Try importing morning_scan module to check for issues
try:
    import sys
    sys.path.insert(0, 'Python')
    import morning_scan
    print("✓ morning_scan module imports successfully")

    # Check that MorningScanner class exists
    if hasattr(morning_scan, 'MorningScanner'):
        print("✓ MorningScanner class found")

        # Check that methods exist
        scanner = morning_scan.MorningScanner.__dict__
        methods = ['_fetch_daily_candidates', '_fallback_symbols', '_build_market_status']
        for method in methods:
            if method in scanner:
                print(f"  ✓ Method {method} exists")
            else:
                print(f"  ✗ Method {method} missing")
    else:
        print("✗ MorningScanner class not found")
        sys.exit(1)

except Exception as e:
    print(f"✗ Error importing morning_scan: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("\nAll checks passed!")
