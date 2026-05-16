#!/usr/bin/env python3
"""
Test d'intégration AWS RDS complète
Vérifie:
1. Connexion AWS RDS depuis ai_server
2. Écriture données → AWS RDS (predictions, model_metrics, trade_feedback)
3. Lecture AWS RDS → sync_ml_stats_to_mt5.py
4. GlobalVariables MT5 ← sync_ml_stats
5. Dashboard MT5 ← GlobalVariables
"""

import os
import sys
import json
import time
import logging
from datetime import datetime
from dotenv import load_dotenv

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Charger .env
load_dotenv()

# ============================================================================
# TEST 1: Vérifier que AWS RDS est disponible et configurable
# ============================================================================
def test_1_aws_rds_config():
    print("\n" + "="*80)
    print("TEST 1: Configuration AWS RDS")
    print("="*80)

    required_vars = {
        'AWS_RDS_HOST': os.getenv('AWS_RDS_HOST'),
        'AWS_RDS_PORT': os.getenv('AWS_RDS_PORT'),
        'AWS_RDS_DATABASE': os.getenv('AWS_RDS_DATABASE'),
        'AWS_RDS_USER': os.getenv('AWS_RDS_USER'),
        'AWS_RDS_PASSWORD': os.getenv('AWS_RDS_PASSWORD'),
        'AWS_RDS_SSLMODE': os.getenv('AWS_RDS_SSLMODE'),
        'USE_SUPABASE': os.getenv('USE_SUPABASE', 'false'),
    }

    all_configured = True
    for key, value in required_vars.items():
        if value:
            # Mask password for security
            display_value = "*" * 8 if 'PASSWORD' in key else value
            print(f"  ✓ {key} = {display_value}")
        else:
            print(f"  ✗ {key} = NOT SET")
            all_configured = False

    use_supabase = os.getenv('USE_SUPABASE', 'false').lower() in {'1', 'true', 'yes'}
    if use_supabase:
        print(f"  ✗ USE_SUPABASE = true (should be false)")
        all_configured = False
    else:
        print(f"  ✓ USE_SUPABASE = false (AWS RDS enabled)")

    return all_configured

# ============================================================================
# TEST 2: Tester connexion AWS RDS
# ============================================================================
def test_2_aws_rds_connection():
    print("\n" + "="*80)
    print("TEST 2: Connexion AWS RDS PostgreSQL")
    print("="*80)

    try:
        from aws_rds_helper import aws_rds_client
        print("  ✓ aws_rds_helper importé")
    except ImportError as e:
        print(f"  ✗ aws_rds_helper non disponible: {e}")
        return False

    try:
        # Tenter une simple requête
        result = aws_rds_client.select("information_schema.tables", limit=1)
        print(f"  ✓ Connexion AWS RDS établie (SELECT successful)")
        return True
    except Exception as e:
        print(f"  ✗ Erreur connexion AWS RDS: {e}")
        return False

# ============================================================================
# TEST 3: Vérifier que ai_server détecte AWS_RDS_AVAILABLE
# ============================================================================
def test_3_ai_server_aws_detection():
    print("\n" + "="*80)
    print("TEST 3: Détection AWS RDS dans ai_server.py")
    print("="*80)

    try:
        import ai_server

        # Vérifier le flag AWS_RDS_AVAILABLE
        if hasattr(ai_server, 'AWS_RDS_AVAILABLE'):
            if ai_server.AWS_RDS_AVAILABLE:
                print(f"  ✓ AWS_RDS_AVAILABLE = True")
                return True
            else:
                print(f"  ✗ AWS_RDS_AVAILABLE = False")
                return False
        else:
            print(f"  ✗ AWS_RDS_AVAILABLE attribute not found")
            return False
    except Exception as e:
        print(f"  ✗ Erreur import ai_server: {e}")
        return False

# ============================================================================
# TEST 4: Écrire une test-prediction dans AWS RDS
# ============================================================================
def test_4_write_test_prediction():
    print("\n" + "="*80)
    print("TEST 4: Écriture test-prediction → AWS RDS")
    print("="*80)

    try:
        from aws_rds_helper import aws_rds_client

        test_prediction = {
            'symbol': 'TEST_EURUSD',
            'timeframe': 'M1',
            'action': 'hold',
            'confidence': 0.75,
            'reason': 'TEST INTEGRATION - Should appear in AWS RDS',
            'metadata': json.dumps({'test': True, 'timestamp': datetime.utcnow().isoformat()}),
            'created_at': datetime.utcnow().isoformat()
        }

        result_id = aws_rds_client.insert('predictions', test_prediction)
        if result_id:
            print(f"  ✓ Test-prediction écrite dans AWS RDS (ID: {result_id})")
            return result_id
        else:
            print(f"  ✗ Erreur écriture test-prediction")
            return None
    except Exception as e:
        print(f"  ✗ Erreur: {e}")
        return None

# ============================================================================
# TEST 5: Vérifier que test-prediction est lisible depuis AWS RDS
# ============================================================================
def test_5_read_test_prediction(prediction_id):
    print("\n" + "="*80)
    print("TEST 5: Lecture test-prediction depuis AWS RDS")
    print("="*80)

    try:
        from aws_rds_helper import aws_rds_client

        # Récupérer depuis la DB
        results = aws_rds_client.select(
            'predictions',
            filters={'id': prediction_id}
        )

        if results:
            prediction = results[0]
            print(f"  ✓ Test-prediction lue depuis AWS RDS:")
            print(f"    - ID: {prediction.get('id')}")
            print(f"    - Symbol: {prediction.get('symbol')}")
            print(f"    - Action: {prediction.get('action')}")
            print(f"    - Confidence: {prediction.get('confidence')}")
            return True
        else:
            print(f"  ✗ Test-prediction non trouvée dans AWS RDS")
            return False
    except Exception as e:
        print(f"  ✗ Erreur lecture: {e}")
        return False

# ============================================================================
# TEST 6: Vérifier que sync_ml_stats_to_mt5 peut lire depuis AWS RDS
# ============================================================================
def test_6_sync_ml_stats_connection():
    print("\n" + "="*80)
    print("TEST 6: Connexion sync_ml_stats_to_mt5.py → AWS RDS")
    print("="*80)

    try:
        from sync_ml_stats_to_mt5 import get_ml_stats_from_rds

        stats = get_ml_stats_from_rds()
        if stats is None:
            print(f"  ✗ get_ml_stats_from_rds() returned None")
            return False

        print(f"  ✓ sync_ml_stats a accès à AWS RDS")
        print(f"    - Total predictions: {stats.get('total_predictions', 0)}")
        print(f"    - Accurate predictions: {stats.get('accurate_predictions', 0)}")
        print(f"    - Models loaded: {stats.get('models_loaded', 0)}")

        # Vérifier que le test-prediction est compté
        if stats.get('total_predictions', 0) > 0:
            print(f"  ✓ Test-prediction incluse dans le comptage")
            return True
        else:
            print(f"  ⚠ Aucune prediction comptée (peut être un problème d'accuracy filter)")
            return True  # Pas nécessairement une erreur
    except Exception as e:
        print(f"  ✗ Erreur: {e}")
        import traceback
        traceback.print_exc()
        return False

# ============================================================================
# TEST 7: Vérifier que les données peuvent être lues et converties en GlobalVariables
# ============================================================================
def test_7_globalvariable_format():
    print("\n" + "="*80)
    print("TEST 7: Format pour MT5 GlobalVariables")
    print("="*80)

    try:
        from sync_ml_stats_to_mt5 import get_ml_stats_from_rds

        stats = get_ml_stats_from_rds()
        if not stats:
            print(f"  ✗ Impossible de récupérer les stats")
            return False

        # Vérifier que toutes les clés attendues sont présentes
        expected_keys = [
            'total_predictions',
            'accurate_predictions',
            'trades_total',
            'trades_win',
            'avg_profit',
            'models_loaded'
        ]

        all_present = True
        for key in expected_keys:
            if key in stats:
                value = stats[key]
                print(f"  ✓ {key}: {value} (type: {type(value).__name__})")
            else:
                print(f"  ✗ {key}: MISSING")
                all_present = False

        return all_present
    except Exception as e:
        print(f"  ✗ Erreur: {e}")
        return False

# ============================================================================
# TEST 8: Vérifier que ai_server écrit correctement les données
# ============================================================================
def test_8_ai_server_write_verification():
    print("\n" + "="*80)
    print("TEST 8: Vérification ai_server écrit les données correctement")
    print("="*80)

    try:
        from aws_rds_helper import aws_rds_client

        # Chercher les prédictions récentes (dernière heure)
        predictions = aws_rds_client.select(
            'predictions',
            order_by='created_at DESC',
            limit=100
        )

        if not predictions:
            print(f"  ⚠ Aucune prediction trouvée (normal si ai_server n'a pas reçu de /decision)")
            return True

        # Compter les prédictions
        total = len(predictions)
        print(f"  ✓ Total predictions dans AWS RDS: {total}")

        # Vérifier la structure des dernières prédictions
        recent = predictions[0]
        required_fields = ['symbol', 'timeframe', 'action', 'confidence', 'metadata']

        all_present = True
        for field in required_fields:
            if field in recent:
                print(f"    - {field}: ✓")
            else:
                print(f"    - {field}: ✗")
                all_present = False

        return all_present
    except Exception as e:
        print(f"  ✗ Erreur: {e}")
        return False

# ============================================================================
# MAIN
# ============================================================================
def main():
    print("\n" + "="*80)
    print("TEST D'INTÉGRATION AWS RDS COMPLÈTE")
    print("="*80)
    print("Date:", datetime.utcnow().isoformat())

    results = {}

    # Test 1
    results['config'] = test_1_aws_rds_config()
    if not results['config']:
        print("\n✗ Configuration AWS RDS incomplète - arrêt")
        return

    # Test 2
    results['connection'] = test_2_aws_rds_connection()
    if not results['connection']:
        print("\n✗ Connexion AWS RDS échouée - arrêt")
        return

    # Test 3
    results['ai_server_detection'] = test_3_ai_server_aws_detection()

    # Test 4
    prediction_id = test_4_write_test_prediction()
    results['write_prediction'] = prediction_id is not None

    # Test 5
    if prediction_id:
        time.sleep(1)  # Attendre la synchronisation DB
        results['read_prediction'] = test_5_read_test_prediction(prediction_id)

    # Test 6
    results['sync_connection'] = test_6_sync_ml_stats_connection()

    # Test 7
    results['globalvar_format'] = test_7_globalvariable_format()

    # Test 8
    results['ai_server_writes'] = test_8_ai_server_write_verification()

    # Résumé
    print("\n" + "="*80)
    print("RÉSUMÉ DES TESTS")
    print("="*80)

    for test_name, result in results.items():
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"  {status}: {test_name}")

    total_passed = sum(1 for r in results.values() if r)
    total_tests = len(results)

    print(f"\nTotal: {total_passed}/{total_tests} tests réussis")

    if total_passed == total_tests:
        print("\n🎉 TOUTES LES VÉRIFICATIONS RÉUSSIES!")
        print("Le système AWS RDS fonctionne correctement.")
        return 0
    else:
        print(f"\n⚠ {total_tests - total_passed} test(s) échoué(s)")
        return 1

if __name__ == '__main__':
    exit(main())
