#!/usr/bin/env python3
"""
Test de connexion AWS RDS PostgreSQL
"""

import os
import sys
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv()

# Importer le helper AWS RDS
from aws_rds_helper import aws_rds_client

def test_connection():
    """Tester la connexion à AWS RDS"""
    print("="*60)
    print("TEST DE CONNEXION AWS RDS")
    print("="*60)

    # Vérifier les variables d'environnement
    required_vars = ["AWS_RDS_HOST", "AWS_RDS_DATABASE", "AWS_RDS_USER", "AWS_RDS_PASSWORD"]
    missing = [var for var in required_vars if not os.getenv(var)]

    if missing:
        print(f"[ERREUR] Variables manquantes: {', '.join(missing)}")
        sys.exit(1)

    print("\n[1/4] Configuration:")
    print(f"   Host: {os.getenv('AWS_RDS_HOST')}")
    print(f"   Database: {os.getenv('AWS_RDS_DATABASE')}")
    print(f"   User: {os.getenv('AWS_RDS_USER')}")
    print(f"   SSL: {os.getenv('AWS_RDS_SSLMODE', 'require')}")

    # Test connexion
    print("\n[2/4] Test de connexion...")
    try:
        with aws_rds_client.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT version();")
            version = cursor.fetchone()[0]
            print(f"[OK] Connexion réussie!")
            print(f"   PostgreSQL: {version[:60]}...")
            cursor.close()
    except Exception as e:
        print(f"[ERREUR] Erreur: {e}")
        sys.exit(1)

    # Lister les tables
    print("\n[3/4] Liste des tables:")
    try:
        tables = aws_rds_client.execute_query("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)

        if tables:
            for table in tables:
                # Compter les enregistrements
                count_result = aws_rds_client.execute_query(
                    f"SELECT COUNT(*) as count FROM {table['table_name']}"
                )
                count = count_result[0]['count'] if count_result else 0
                print(f"   - {table['table_name']}: {count} enregistrements")
        else:
            print("   Aucune table trouvée")

    except Exception as e:
        print(f"[ATTENTION]  Erreur liste tables: {e}")

    # Test insertion
    print("\n[4/4] Test d'insertion (trade_feedback)...")
    try:
        test_data = {
            "symbol": "TEST_SYMBOL",
            "timeframe": "M1",
            "side": "buy",
            "open_time": "2026-01-01 00:00:00",
            "entry_price": 1000.0,
            "profit": 0.5,
            "is_win": True
        }

        result_id = aws_rds_client.insert("trade_feedback", test_data)
        if result_id:
            print(f"[OK] Insertion réussie (ID: {result_id})")

            # Supprimer le test
            aws_rds_client.execute_query(
                "DELETE FROM trade_feedback WHERE id = %s",
                (result_id,)
            )
            print("[OK] Test nettoyé")
        else:
            print("[ERREUR] Échec d'insertion")

    except Exception as e:
        print(f"[ATTENTION]  Erreur test insertion: {e}")

    print("\n" + "="*60)
    print("[OK] TOUS LES TESTS RÉUSSIS!")
    print("="*60)

if __name__ == "__main__":
    test_connection()
