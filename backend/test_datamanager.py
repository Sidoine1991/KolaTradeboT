"""
Test du module DataManager
"""
import pytest
from backend.core.data_manager import DataManager
from datetime import datetime, timedelta

@pytest.fixture(scope="module")
def dm():
    return DataManager()

def test_get_historical_data_valid(dm):
    df = dm.get_historical_data('EURUSD', 'M5', count=10)
    assert df is not None, "Le DataFrame ne doit pas être None"
    assert not df.empty, "Le DataFrame ne doit pas être vide"
    for col in ['open', 'high', 'low', 'close', 'volume']:
        assert col in df.columns, f"Colonne manquante: {col}"

def test_get_historical_data_invalid_symbol(dm):
    df = dm.get_historical_data('INVALID', 'M5', count=10)
    assert df is None or df.empty, "Le DataFrame doit être vide pour un symbole invalide"

def test_get_historical_data_invalid_timeframe(dm):
    df = dm.get_historical_data('EURUSD', 'INVALID', count=10)
    assert df is None or df.empty, "Le DataFrame doit être vide pour un timeframe invalide"

def test_get_historical_data_empty_range(dm):
    # Plage de dates future, donc vide
    start = datetime.now() + timedelta(days=10)
    end = start + timedelta(days=1)
    df = dm.get_historical_data('EURUSD', 'M5', from_date=start, to_date=end)
    assert df is None or df.empty, "Le DataFrame doit être vide pour une plage de dates sans données"
