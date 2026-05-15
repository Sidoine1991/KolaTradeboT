#!/usr/bin/env python3
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
from dotenv import load_dotenv

# Charger les variables d'environnement depuis .env
load_dotenv()

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
