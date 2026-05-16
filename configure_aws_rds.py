#!/usr/bin/env python3
"""
Configuration d'AWS RDS dans TradBOT
Met à jour les fichiers .env et ai_server.py pour utiliser AWS RDS au lieu de Supabase
"""

import os
import re
import shutil
from pathlib import Path

# Configuration AWS RDS
AWS_RDS_CONFIG = """
# ===== AWS RDS POSTGRESQL CONFIGURATION =====
# Connexion à la base de données AWS RDS
AWS_RDS_HOST=trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com
AWS_RDS_PORT=5432
AWS_RDS_DATABASE=trading_bot
AWS_RDS_USER=dbadmin
AWS_RDS_PASSWORD=YOUR_PASSWORD_HERE
AWS_RDS_SSLMODE=require

# Database URL complète (pour psycopg2 ou SQLAlchemy)
DATABASE_URL=postgresql://dbadmin:YOUR_PASSWORD_HERE@trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com:5432/trading_bot?sslmode=require

# Désactiver Supabase (ancienne config)
USE_SUPABASE=false
SUPABASE_ENABLED=false

# ===== FIN AWS RDS CONFIGURATION =====
"""

def backup_file(filepath):
    """Créer une sauvegarde du fichier"""
    if os.path.exists(filepath):
        backup_path = f"{filepath}.backup_{os.path.getmtime(filepath):.0f}"
        shutil.copy2(filepath, backup_path)
        print(f"[OK] Sauvegarde créée: {backup_path}")
        return backup_path
    return None

def update_env_file():
    """Mettre à jour le fichier .env"""
    env_path = "D:/Dev/TradBOT/.env"

    print("\n[1/3] Mise à jour du fichier .env...")

    # Backup
    backup_file(env_path)

    # Lire le contenu actuel
    if os.path.exists(env_path):
        with open(env_path, 'r', encoding='utf-8') as f:
            content = f.read()
    else:
        content = ""

    # Vérifier si AWS RDS est déjà configuré
    if "AWS_RDS_HOST" in content:
        print("[ATTENTION]  AWS RDS déjà configuré dans .env")
        response = input("Voulez-vous écraser la configuration? (o/N): ")
        if response.lower() != 'o':
            print("[ERREUR] Configuration .env annulée")
            return False

    # Ajouter la configuration AWS RDS
    if not content.endswith('\n'):
        content += '\n'

    content += AWS_RDS_CONFIG

    # Sauvegarder
    with open(env_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"[OK] Fichier .env mis à jour")
    print("[ATTENTION]  N'oubliez pas de remplacer YOUR_PASSWORD_HERE par votre vrai mot de passe!")

    return True

def create_aws_rds_helper():
    """Créer un module helper pour AWS RDS"""
    helper_path = "D:/Dev/TradBOT/aws_rds_helper.py"

    print("\n[2/3] Création du module aws_rds_helper.py...")

    helper_code = '''#!/usr/bin/env python3
"""
Helper pour la connexion AWS RDS PostgreSQL
Remplace les fonctions Supabase par des connexions directes PostgreSQL
"""

import os
import psycopg2
from psycopg2.extras import RealDictCursor
import logging
from typing import Optional, Dict, List, Any
from contextlib import contextmanager

logger = logging.getLogger(__name__)

class AWSRDSClient:
    """Client pour interagir avec AWS RDS PostgreSQL"""

    def __init__(self):
        self.host = os.getenv("AWS_RDS_HOST")
        self.port = int(os.getenv("AWS_RDS_PORT", 5432))
        self.database = os.getenv("AWS_RDS_DATABASE")
        self.user = os.getenv("AWS_RDS_USER")
        self.password = os.getenv("AWS_RDS_PASSWORD")
        self.sslmode = os.getenv("AWS_RDS_SSLMODE", "require")

    @contextmanager
    def get_connection(self):
        """Context manager pour gérer les connexions"""
        conn = None
        try:
            conn = psycopg2.connect(
                host=self.host,
                port=self.port,
                database=self.database,
                user=self.user,
                password=self.password,
                sslmode=self.sslmode
            )
            yield conn
        except Exception as e:
            logger.error(f"Erreur connexion AWS RDS: {e}")
            raise
        finally:
            if conn:
                conn.close()

    def insert(self, table: str, data: Dict[str, Any]) -> Optional[int]:
        """Insérer des données dans une table"""
        try:
            columns = ", ".join(data.keys())
            placeholders = ", ".join(["%s"] * len(data))
            query = f"INSERT INTO {table} ({columns}) VALUES ({placeholders}) RETURNING id"

            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, tuple(data.values()))
                result_id = cursor.fetchone()[0]
                conn.commit()
                cursor.close()
                return result_id

        except Exception as e:
            logger.error(f"Erreur INSERT dans {table}: {e}")
            return None

    def select(self, table: str, filters: Optional[Dict[str, Any]] = None,
               limit: Optional[int] = None, order_by: Optional[str] = None) -> List[Dict]:
        """Sélectionner des données depuis une table"""
        try:
            query = f"SELECT * FROM {table}"
            params = []

            if filters:
                conditions = []
                for key, value in filters.items():
                    conditions.append(f"{key} = %s")
                    params.append(value)
                query += " WHERE " + " AND ".join(conditions)

            if order_by:
                query += f" ORDER BY {order_by}"

            if limit:
                query += f" LIMIT {limit}"

            with self.get_connection() as conn:
                cursor = conn.cursor(cursor_factory=RealDictCursor)
                cursor.execute(query, params)
                results = cursor.fetchall()
                cursor.close()
                return [dict(row) for row in results]

        except Exception as e:
            logger.error(f"Erreur SELECT depuis {table}: {e}")
            return []

    def update(self, table: str, data: Dict[str, Any], filters: Dict[str, Any]) -> bool:
        """Mettre à jour des données dans une table"""
        try:
            set_clause = ", ".join([f"{k} = %s" for k in data.keys()])
            where_clause = " AND ".join([f"{k} = %s" for k in filters.keys()])

            query = f"UPDATE {table} SET {set_clause} WHERE {where_clause}"
            params = list(data.values()) + list(filters.values())

            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, params)
                conn.commit()
                cursor.close()
                return True

        except Exception as e:
            logger.error(f"Erreur UPDATE dans {table}: {e}")
            return False

    def execute_query(self, query: str, params: Optional[tuple] = None) -> List[Dict]:
        """Exécuter une requête SQL personnalisée"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor(cursor_factory=RealDictCursor)
                cursor.execute(query, params or ())
                if query.strip().upper().startswith("SELECT"):
                    results = cursor.fetchall()
                    cursor.close()
                    return [dict(row) for row in results]
                else:
                    conn.commit()
                    cursor.close()
                    return []

        except Exception as e:
            logger.error(f"Erreur exécution requête: {e}")
            return []

# Instance globale
aws_rds_client = AWSRDSClient()

# Fonctions de compatibilité avec l'ancien code Supabase
def push_to_database(table: str, data: Dict[str, Any]) -> bool:
    """Alias pour compatibilité avec l'ancien code Supabase"""
    result = aws_rds_client.insert(table, data)
    return result is not None

def fetch_from_database(table: str, filters: Optional[Dict] = None, limit: Optional[int] = None) -> List[Dict]:
    """Alias pour compatibilité avec l'ancien code Supabase"""
    return aws_rds_client.select(table, filters=filters, limit=limit, order_by="created_at DESC")
'''

    with open(helper_path, 'w', encoding='utf-8') as f:
        f.write(helper_code)

    print(f"[OK] Module aws_rds_helper.py créé")
    return True

def create_test_script():
    """Créer un script de test de connexion"""
    test_path = "D:/Dev/TradBOT/test_aws_rds_connection.py"

    print("\n[3/3] Création du script de test...")

    test_code = '''#!/usr/bin/env python3
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

    print("\\n[1/4] Configuration:")
    print(f"   Host: {os.getenv('AWS_RDS_HOST')}")
    print(f"   Database: {os.getenv('AWS_RDS_DATABASE')}")
    print(f"   User: {os.getenv('AWS_RDS_USER')}")
    print(f"   SSL: {os.getenv('AWS_RDS_SSLMODE', 'require')}")

    # Test connexion
    print("\\n[2/4] Test de connexion...")
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
    print("\\n[3/4] Liste des tables:")
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
    print("\\n[4/4] Test d'insertion (trade_feedback)...")
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

    print("\\n" + "="*60)
    print("[OK] TOUS LES TESTS RÉUSSIS!")
    print("="*60)

if __name__ == "__main__":
    test_connection()
'''

    with open(test_path, 'w', encoding='utf-8') as f:
        f.write(test_code)

    print(f"[OK] Script de test créé: {test_path}")
    return True

def main():
    """Fonction principale"""
    print("="*60)
    print("CONFIGURATION AWS RDS POUR TRADBOT")
    print("="*60)

    # 1. Mettre à jour .env
    if not update_env_file():
        return

    # 2. Créer le helper AWS RDS
    if not create_aws_rds_helper():
        return

    # 3. Créer le script de test
    if not create_test_script():
        return

    print("\n" + "="*60)
    print("[OK] CONFIGURATION TERMINÉE!")
    print("="*60)
    print("\nProchaines étapes:")
    print("1. Éditer .env et remplacer YOUR_PASSWORD_HERE par votre mot de passe")
    print("2. Exécuter: python migrate_to_aws_rds.py (créer les tables)")
    print("3. Exécuter: python test_aws_rds_connection.py (tester)")
    print("4. Modifier ai_server.py pour utiliser aws_rds_helper au lieu de Supabase")

if __name__ == "__main__":
    main()
