#!/usr/bin/env python3
"""
Test de vérification: AUCUN appel Supabase quand USE_SUPABASE=false
"""

import os
os.environ["USE_SUPABASE"] = "false"
os.environ["AWS_RDS_HOST"] = "trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com"
os.environ["AWS_RDS_PORT"] = "5432"
os.environ["AWS_RDS_DATABASE"] = "trading_bot"
os.environ["AWS_RDS_USER"] = "dbadmin"
os.environ["AWS_RDS_PASSWORD"] = "REMOVED_DB_PASSWORD"
os.environ["AWS_RDS_SSLMODE"] = "require"

# Simuler Supabase configuré (mais USE_SUPABASE=false doit bloquer)
os.environ["SUPABASE_URL"] = "https://fake-should-not-be-used.supabase.co"
os.environ["SUPABASE_SERVICE_KEY"] = "fake_key_should_not_be_used"

print("[TEST] Vérification blocage Supabase avec USE_SUPABASE=false")
print(f"  USE_SUPABASE={os.getenv('USE_SUPABASE')}")
print(f"  SUPABASE_URL={os.getenv('SUPABASE_URL')}")
print(f"  SUPABASE_SERVICE_KEY={'*' * 10 if os.getenv('SUPABASE_SERVICE_KEY') else 'NON_DEFINI'}")
print()

# Import après avoir défini les variables
import sys
sys.path.insert(0, os.path.dirname(__file__))

# Mock httpx pour capturer les appels HTTP
http_calls = []

class MockHTTPClient:
    def __init__(self, *args, **kwargs):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        pass

    async def post(self, url, *args, **kwargs):
        http_calls.append(("POST", url))
        class MockResponse:
            status_code = 201
            def json(self):
                return {}
        return MockResponse()

    async def get(self, url, *args, **kwargs):
        http_calls.append(("GET", url))
        class MockResponse:
            status_code = 200
            def json(self):
                return []
        return MockResponse()

    async def patch(self, url, *args, **kwargs):
        http_calls.append(("PATCH", url))
        class MockResponse:
            status_code = 200
        return MockResponse()

# Remplacer httpx
import httpx
original_AsyncClient = httpx.AsyncClient
httpx.AsyncClient = MockHTTPClient

# Importer ai_server après mock
from ai_server import (
    _get_supabase_config,
    _supabase_credentials_ready,
    _stair_fetch_quality_rows,
    _insert_stair_detection_supabase,
    _patch_stair_outcome_supabase,
)

import asyncio

async def test_supabase_disabled():
    print("[TEST 1] _get_supabase_config() doit retourner ('', '')")
    url, key = _get_supabase_config(strict=False)
    assert url == "", f"ÉCHEC: url={url}, attendu=''"
    assert key == "", f"ÉCHEC: key={key}, attendu=''"
    print("  [OK] Retourne ('', '')")
    print()

    print("[TEST 2] _supabase_credentials_ready() doit retourner False")
    ready = _supabase_credentials_ready()
    assert ready == False, f"ÉCHEC: ready={ready}, attendu=False"
    print("  [OK] Retourne False")
    print()

    print("[TEST 3] _stair_fetch_quality_rows() ne doit PAS appeler Supabase")
    http_calls.clear()
    rows = await _stair_fetch_quality_rows("Boom 300 Index", "BUY")
    supabase_calls = [call for call in http_calls if "supabase" in call[1]]
    assert len(supabase_calls) == 0, f"ÉCHEC: {len(supabase_calls)} appels Supabase trouvés: {supabase_calls}"
    print(f"  [OK] Aucun appel Supabase (total HTTP: {len(http_calls)})")
    print()

    print("[TEST 4] _insert_stair_detection_supabase() ne doit PAS appeler Supabase")
    http_calls.clear()
    await _insert_stair_detection_supabase({"symbol": "TEST", "pattern_type": "test"})
    supabase_calls = [call for call in http_calls if "supabase" in call[1]]
    assert len(supabase_calls) == 0, f"ÉCHEC: {len(supabase_calls)} appels Supabase trouvés: {supabase_calls}"
    print(f"  [OK] Aucun appel Supabase (total HTTP: {len(http_calls)})")
    print()

    print("[TEST 5] _patch_stair_outcome_supabase() ne doit PAS appeler Supabase")
    http_calls.clear()
    result = await _patch_stair_outcome_supabase(
        row_id="123",
        outcome="win",
        result_usd=0.85
    )
    supabase_calls = [call for call in http_calls if "supabase" in call[1]]
    assert len(supabase_calls) == 0, f"ÉCHEC: {len(supabase_calls)} appels Supabase trouvés: {supabase_calls}"
    print(f"  [OK] Aucun appel Supabase (total HTTP: {len(http_calls)})")
    print()

    print("="*60)
    print("[SUCCÈS] TOUS LES TESTS RÉUSSIS")
    print("="*60)
    print()
    print("Résumé:")
    print("  - _get_supabase_config() bloqué ✓")
    print("  - _supabase_credentials_ready() bloqué ✓")
    print("  - _stair_fetch_quality_rows() bloqué ✓")
    print("  - _insert_stair_detection_supabase() bloqué ✓")
    print("  - _patch_stair_outcome_supabase() bloqué ✓")
    print()
    print("Conclusion:")
    print("  Avec USE_SUPABASE=false, AUCUN appel HTTP vers Supabase n'est effectué.")
    print("  Le système utilise exclusivement AWS RDS PostgreSQL.")

if __name__ == "__main__":
    asyncio.run(test_supabase_disabled())
