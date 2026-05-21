#!/usr/bin/env python3
"""
Helper pour la connexion AWS RDS PostgreSQL
Remplace les fonctions Supabase par des connexions directes PostgreSQL
"""

import os
import json
import psycopg2
from psycopg2.extras import RealDictCursor
import logging
from typing import Optional, Dict, List, Any, Tuple
from contextlib import contextmanager
from datetime import datetime, timezone
from dotenv import load_dotenv

# Charger les variables d'environnement depuis .env
load_dotenv()

logger = logging.getLogger(__name__)

class AWSRDSClient:
    """Client pour interagir avec AWS RDS PostgreSQL"""

    def __init__(self):
        # Accepte AWS_RDS_* (standard) ou RDS_* (legacy python/.env)
        self.host = os.getenv("AWS_RDS_HOST") or os.getenv("RDS_HOST")
        self.port = int(os.getenv("AWS_RDS_PORT") or os.getenv("RDS_PORT") or 5432)
        self.database = os.getenv("AWS_RDS_DATABASE") or os.getenv("RDS_DATABASE")
        self.user = os.getenv("AWS_RDS_USER") or os.getenv("RDS_USER")
        self.password = os.getenv("AWS_RDS_PASSWORD") or os.getenv("RDS_PASSWORD")
        self.sslmode = os.getenv("AWS_RDS_SSLMODE") or os.getenv("RDS_SSLMODE") or "require"
        if not self.host:
            logger.warning("AWS RDS: host non configuré (AWS_RDS_HOST / RDS_HOST)")

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

    # ------------------------------------------------------------------
    # Helpers for new tables added in migration_optimize_rds.sql
    # ------------------------------------------------------------------

    def upsert_setup_score(
        self,
        symbol: str,
        setup_score: float,
        *,
        timeframe: str = "M1",
        win_rate: Optional[float] = None,
        expectancy: Optional[float] = None,
        propice_score: Optional[float] = None,
        trade_count: Optional[int] = None,
        direction: Optional[str] = None,
        hour_utc: Optional[int] = None,
        atr_value: Optional[float] = None,
        rank_position: Optional[int] = None,
        in_top3: bool = False,
        source: str = "server",
    ) -> Optional[int]:
        """
        Insert a new setup-score row for a symbol into symbol_setup_scores.
        Each call creates a new timestamped snapshot (append-only log).
        Returns the inserted row id or None on error.
        """
        data: Dict[str, Any] = {
            "symbol": symbol,
            "timeframe": timeframe,
            "setup_score": round(float(setup_score), 4),
            "in_top3": in_top3,
            "source": source,
        }
        if win_rate is not None:
            data["win_rate"] = round(float(win_rate), 4)
        if expectancy is not None:
            data["expectancy"] = round(float(expectancy), 4)
        if propice_score is not None:
            data["propice_score"] = round(float(propice_score), 6)
        if trade_count is not None:
            data["trade_count"] = int(trade_count)
        if direction is not None:
            data["direction"] = direction.upper()
        if hour_utc is not None:
            data["hour_utc"] = int(hour_utc)
        if atr_value is not None:
            data["atr_value"] = float(atr_value)
        if rank_position is not None:
            data["rank_position"] = int(rank_position)
        return self.insert("symbol_setup_scores", data)

    def insert_spike_event(
        self,
        symbol: str,
        direction: str,
        atr_multiplier: float,
        atr_value: float,
        *,
        timeframe: str = "M1",
        spike_points: Optional[float] = None,
        entry_price: Optional[float] = None,
        exit_price: Optional[float] = None,
        profit_usd: Optional[float] = None,
        profit_captured: bool = False,
        spike_started_at: Optional[str] = None,
        spike_closed_at: Optional[str] = None,
        duration_seconds: Optional[int] = None,
        hour_utc: Optional[int] = None,
        session_tag: Optional[str] = None,
        prior_setup_score: Optional[float] = None,
        prior_spike_prob: Optional[float] = None,
        features: Optional[Dict[str, Any]] = None,
        mt5_ticket: Optional[int] = None,
        source: str = "ea",
    ) -> Optional[int]:
        """
        Record a spike detection event into spike_detection_events.
        Returns the inserted row id or None on error.
        """
        data: Dict[str, Any] = {
            "symbol": symbol,
            "timeframe": timeframe,
            "direction": direction.upper(),
            "atr_multiplier": round(float(atr_multiplier), 4),
            "atr_value": float(atr_value),
            "profit_captured": bool(profit_captured),
            "features": json.dumps(features or {}),
            "source": source,
        }
        for key, val in [
            ("spike_points", spike_points),
            ("entry_price", entry_price),
            ("exit_price", exit_price),
            ("profit_usd", profit_usd),
            ("spike_started_at", spike_started_at),
            ("spike_closed_at", spike_closed_at),
            ("duration_seconds", duration_seconds),
            ("hour_utc", hour_utc),
            ("session_tag", session_tag),
            ("prior_setup_score", prior_setup_score),
            ("prior_spike_prob", prior_spike_prob),
            ("mt5_ticket", mt5_ticket),
        ]:
            if val is not None:
                data[key] = val
        return self.insert("spike_detection_events", data)

    def insert_verdict_entry(
        self,
        symbol: str,
        verdict_label: str,
        verdict_num: float,
        ia_direction: str,
        entry_price: float,
        *,
        timeframe: str = "M1",
        ia_confidence: Optional[float] = None,
        prediction_direction: Optional[str] = None,
        trend_direction: Optional[str] = None,
        ema9_m1: Optional[float] = None,
        ema21_m1: Optional[float] = None,
        ema9_m5: Optional[float] = None,
        ema21_m5: Optional[float] = None,
        stop_loss: Optional[float] = None,
        take_profit: Optional[float] = None,
        session_tag: Optional[str] = None,
        hour_utc: Optional[int] = None,
        mt5_ticket: Optional[int] = None,
        ml_score: Optional[float] = None,
        spike_prob: Optional[float] = None,
        setup_score: Optional[float] = None,
        entered_at: Optional[str] = None,
    ) -> Optional[int]:
        """
        Record a GOOD/PERFECT verdict entry into verdict_entry_quality.
        Returns the inserted row id or None on error.
        Call update_verdict_outcome() when the trade closes.
        """
        data: Dict[str, Any] = {
            "symbol": symbol,
            "timeframe": timeframe,
            "verdict_label": verdict_label.upper(),
            "verdict_num": round(float(verdict_num), 3),
            "ia_direction": ia_direction.upper(),
            "entry_price": float(entry_price),
            "result": "OPEN",
        }
        for key, val in [
            ("ia_confidence", ia_confidence),
            ("prediction_direction", prediction_direction),
            ("trend_direction", trend_direction),
            ("ema9_m1", ema9_m1),
            ("ema21_m1", ema21_m1),
            ("ema9_m5", ema9_m5),
            ("ema21_m5", ema21_m5),
            ("stop_loss", stop_loss),
            ("take_profit", take_profit),
            ("session_tag", session_tag),
            ("hour_utc", hour_utc),
            ("mt5_ticket", mt5_ticket),
            ("ml_score", ml_score),
            ("spike_prob", spike_prob),
            ("setup_score", setup_score),
            ("entered_at", entered_at),
        ]:
            if val is not None:
                data[key] = val
        return self.insert("verdict_entry_quality", data)

    def update_verdict_outcome(
        self,
        row_id: int,
        result: str,
        exit_price: float,
        profit_usd: float,
        pips: float,
        duration_min: int,
        *,
        risk_reward: Optional[float] = None,
        closed_at: Optional[str] = None,
    ) -> bool:
        """
        Backfill outcome fields on a verdict_entry_quality row once the trade closes.
        result must be WIN | LOSS | BREAKEVEN.
        """
        data: Dict[str, Any] = {
            "result": result.upper(),
            "exit_price": float(exit_price),
            "profit_usd": round(float(profit_usd), 4),
            "pips": round(float(pips), 4),
            "duration_min": int(duration_min),
            "closed_at": closed_at or datetime.now(timezone.utc).isoformat(),
        }
        if risk_reward is not None:
            data["risk_reward"] = float(risk_reward)
        return self.update("verdict_entry_quality", data, {"id": row_id})

    def get_latest_setup_scores(
        self,
        symbols: Optional[List[str]] = None,
        top_n: Optional[int] = None,
    ) -> List[Dict]:
        """
        Return the latest setup score row per symbol from v_latest_setup_scores.
        Optionally filter to a list of symbols or return only the top-N by score.
        """
        query = "SELECT * FROM v_latest_setup_scores"
        params: list = []
        if symbols:
            placeholders = ", ".join(["%s"] * len(symbols))
            query += f" WHERE symbol IN ({placeholders})"
            params.extend(symbols)
        query += " ORDER BY setup_score DESC"
        if top_n:
            query += f" LIMIT {int(top_n)}"
        return self.execute_query(query, tuple(params) if params else None)

    def get_verdict_win_rates(
        self, symbol: Optional[str] = None
    ) -> List[Dict]:
        """
        Return aggregated win rates per verdict_label per symbol from v_verdict_win_rate.
        """
        query = "SELECT * FROM v_verdict_win_rate"
        params: tuple = ()
        if symbol:
            query += " WHERE symbol = %s"
            params = (symbol,)
        query += " ORDER BY symbol, verdict_label"
        return self.execute_query(query, params or None)

    def get_spike_quality_by_hour(
        self, symbol: Optional[str] = None
    ) -> List[Dict]:
        """
        Return spike capture rates by symbol/direction/hour from v_spike_quality_by_hour.
        """
        query = "SELECT * FROM v_spike_quality_by_hour"
        params: tuple = ()
        if symbol:
            query += " WHERE symbol = %s"
            params = (symbol,)
        query += " ORDER BY symbol, direction, hour_utc"
        return self.execute_query(query, params or None)

    def get_trade_feedback_win_rate(
        self,
        symbol: str,
        timeframe: str = "M1",
        lookback_days: int = 30,
        side: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Compute win rate + net profit for a symbol from trade_feedback.
        Replaces the ad-hoc query in _fetch_trade_feedback_stats_from_rds().
        Returns: {wins, losses, total, win_rate, net_profit}
        """
        base = """
            SELECT
                COUNT(*) FILTER (WHERE is_win = true)                AS wins,
                COUNT(*) FILTER (WHERE is_win = false)               AS losses,
                COUNT(*)                                              AS total,
                COALESCE(SUM(profit), 0)                             AS net_profit
            FROM trade_feedback
            WHERE symbol = %s
              AND timeframe = %s
              AND close_time >= NOW() - INTERVAL '%s days'
        """
        args: List[Any] = [symbol, timeframe, lookback_days]
        if side:
            base += " AND side = %s"
            args.append(side.lower())
        rows = self.execute_query(base % tuple(["%s"] * len(args)), tuple(args))
        if rows:
            r = rows[0]
            total = int(r.get("total") or 0)
            wins = int(r.get("wins") or 0)
            return {
                "wins": wins,
                "losses": int(r.get("losses") or 0),
                "total": total,
                "win_rate": round(wins / total, 4) if total > 0 else 0.0,
                "net_profit": float(r.get("net_profit") or 0.0),
            }
        return {"wins": 0, "losses": 0, "total": 0, "win_rate": 0.0, "net_profit": 0.0}


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
