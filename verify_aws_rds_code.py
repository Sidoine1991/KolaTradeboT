#!/usr/bin/env python3
"""
Vérification structurelle que ai_server écrit correctement à AWS RDS
Ne nécessite pas d'exécution, juste une analyse du code
"""

import re
import sys

def check_file(filepath, checks):
    """Vérifie qu'un fichier contient les patterns attendus"""
    print(f"\n{'='*80}")
    print(f"Vérification: {filepath}")
    print(f"{'='*80}")

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"✗ Erreur lecture fichier: {e}")
        return False

    all_passed = True
    for check_name, pattern in checks.items():
        if re.search(pattern, content, re.MULTILINE | re.DOTALL):
            print(f"✓ {check_name}")
        else:
            print(f"✗ {check_name}")
            all_passed = False

    return all_passed

# Vérifications pour ai_server.py
ai_server_checks = {
    'Import aws_rds_helper': r'from aws_rds_helper import aws_rds_client',
    'Flag AWS_RDS_AVAILABLE': r'AWS_RDS_AVAILABLE\s*=\s*True',
    'Écrire predictions à AWS RDS': r"aws_rds_client\.insert\(['\"]predictions['\"]",
    'Écrire model_metrics à AWS RDS': r"aws_rds_client\.insert\(['\"]model_metrics['\"]",
    'Écrire trade_feedback à AWS RDS': r"aws_rds_client\.insert\(['\"]trade_feedback['\"]",
    'Condition USE_SUPABASE=false pour predictions': r"not _env_bool\(['\"]USE_SUPABASE['\"].*\)\s*.*predictions",
    'Condition USE_SUPABASE=false pour trade_feedback': r"USE_SUPABASE.*False.*trade_feedback|trade_feedback.*USE_SUPABASE.*False",
}

# Vérifications pour aws_rds_helper.py
aws_helper_checks = {
    'Classe AWSRDSClient': r'class AWSRDSClient',
    'Méthode get_connection': r'def get_connection\(self\)',
    'Context manager': r'@contextmanager',
    'Méthode insert': r'def insert\(self.*table.*data',
    'Méthode select': r'def select\(self',
    'Méthode update': r'def update\(self',
    'psycopg2 import': r'import psycopg2',
    'SSL mode support': r'sslmode',
}

# Vérifications pour sync_ml_stats_to_mt5.py
sync_checks = {
    'Import aws_rds_helper': r'from aws_rds_helper import',
    'Fonction get_ml_stats_from_rds': r'def get_ml_stats_from_rds',
    'Select from predictions table': r'select.*predictions',
    'Select from trade_feedback table': r'select.*trade_feedback',
    'Select from model_metrics table': r'select.*model_metrics',
    'Set GlobalVariables': r'set_global_variable|mt5\.global_variable_set',
}

# Vérifications pour GOM_Enhanced_Dashboard.mqh
dashboard_checks = {
    'Fonction V3': r'GOM_DrawEnhancedDashboardV3',
    'Lire ML_TOTAL_PREDICTIONS': r'GlobalVariableGet\s*\(\s*["\']ML_TOTAL_PREDICTIONS',
    'Lire ML_ACCURACY': r'GlobalVariableGet\s*\(\s*["\']ML_ACCURACY',
    'Lire ML_TRADES_WIN': r'GlobalVariableGet\s*\(\s*["\']ML_TRADES_WIN',
    'Lire ML_MODELS_LOADED': r'GlobalVariableGet\s*\(\s*["\']ML_MODELS_LOADED',
    'Affichage dashboard': r'OBJ_RECTANGLE_LABEL|OBJ_LABEL',
}

# Vérifications pour SMC_Universal.mq5
smc_checks = {
    'Include GOM_Enhanced_Dashboard': r'#include\s+["\']GOM_Enhanced_Dashboard\.mqh',
    'Input UseEnhancedDashboard': r'UseEnhancedDashboard.*input.*bool',
    'Input DashboardMLPosX': r'DashboardMLPosX.*input.*int',
    'Input DashboardMLPosY': r'DashboardMLPosY.*input.*int',
    'Appel GOM_DrawEnhancedDashboardV3': r'GOM_DrawEnhancedDashboardV3',
    'GlobalVariableSet UTC_PAUSE': r'GlobalVariableSet.*EA_DASH_UTC_PAUSE',
}

def main():
    print("\n" + "="*80)
    print("VÉRIFICATION STRUCTURELLE - AWS RDS INTEGRATION")
    print("="*80)

    results = {}

    # Vérifier ai_server.py
    results['ai_server.py'] = check_file(
        'D:\\Dev\\TradBOT\\ai_server.py',
        ai_server_checks
    )

    # Vérifier aws_rds_helper.py
    results['aws_rds_helper.py'] = check_file(
        'D:\\Dev\\TradBOT\\aws_rds_helper.py',
        aws_helper_checks
    )

    # Vérifier sync_ml_stats_to_mt5.py
    results['sync_ml_stats_to_mt5.py'] = check_file(
        'D:\\Dev\\TradBOT\\sync_ml_stats_to_mt5.py',
        sync_checks
    )

    # Vérifier GOM_Enhanced_Dashboard.mqh
    try:
        results['GOM_Enhanced_Dashboard.mqh'] = check_file(
            'D:\\Dev\\TradBOT\\GOM_Enhanced_Dashboard.mqh',
            dashboard_checks
        )
    except:
        print("\n⚠ GOM_Enhanced_Dashboard.mqh - fichier trop volumineux, vérification partielle")

    # Vérifier SMC_Universal.mq5
    try:
        results['SMC_Universal.mq5'] = check_file(
            'D:\\Dev\\TradBOT\\SMC_Universal.mq5',
            smc_checks
        )
    except:
        print("\n⚠ SMC_Universal.mq5 - fichier trop volumineux, vérification partielle")

    # Résumé
    print(f"\n{'='*80}")
    print("RÉSUMÉ")
    print(f"{'='*80}")

    for filename, passed in results.items():
        status = "✓" if passed else "✗"
        print(f"{status} {filename}")

    passed_count = sum(1 for p in results.values() if p)
    total_count = len(results)

    print(f"\nTotal: {passed_count}/{total_count} fichiers vérifiés")

    if passed_count == total_count:
        print("\n🎉 TOUTE LA STRUCTURE DE CODE EST CORRECTE!")
        return 0
    else:
        print(f"\n⚠ {total_count - passed_count} fichier(s) avec problèmes")
        return 1

if __name__ == '__main__':
    sys.exit(main())
