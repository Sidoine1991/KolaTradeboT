#!/usr/bin/env python3
"""
Calcule et synchronise les stats de trades par symbole (jour + mois) dans Supabase (Postgres),
puis exporte un fichier Excel (Daily + Monthly).

Source des données: table `trade_feedback` (feedback issu de MT5 / EA).
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import datetime, timezone, timedelta, date
from pathlib import Path
from typing import Iterable, Optional

import asyncpg
import pandas as pd
from dotenv import load_dotenv
from urllib.parse import urlparse
import socket
import requests
from urllib.parse import urlencode


@dataclass(frozen=True)
class Period:
    period_type: str  # "day" | "month"
    period_start: date
    from_ts: datetime
    to_ts: datetime


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _day_period(now: datetime) -> Period:
    d = now.date()
    from_ts = datetime(d.year, d.month, d.day, tzinfo=timezone.utc)
    to_ts = now
    return Period(period_type="day", period_start=d, from_ts=from_ts, to_ts=to_ts)


def _month_period(now: datetime) -> Period:
    d = date(now.year, now.month, 1)
    from_ts = datetime(d.year, d.month, d.day, tzinfo=timezone.utc)
    to_ts = now
    return Period(period_type="month", period_start=d, from_ts=from_ts, to_ts=to_ts)


async def _fetch_stats(conn: asyncpg.Connection, period: Period, timeframe: str = "M1") -> pd.DataFrame:
    """
    Agrège trade_feedback sur une fenêtre.
    Hypothèses: colonnes `symbol`, `profit`, `is_win`, `created_at`.
    """
    rows = await conn.fetch(
        """
        SELECT
            symbol,
            COUNT(*)::int AS trade_count,
            SUM(CASE WHEN is_win THEN 1 ELSE 0 END)::int AS wins,
            SUM(CASE WHEN (NOT is_win) THEN 1 ELSE 0 END)::int AS losses,
            COALESCE(SUM(profit), 0)::numeric AS net_profit,
            COALESCE(SUM(CASE WHEN profit > 0 THEN profit ELSE 0 END), 0)::numeric AS gross_profit,
            COALESCE(SUM(CASE WHEN profit < 0 THEN -profit ELSE 0 END), 0)::numeric AS gross_loss,
            MAX(created_at) AS last_trade_at
        FROM trade_feedback
        WHERE created_at >= $1 AND created_at <= $2
        GROUP BY symbol
        ORDER BY symbol
        """,
        period.from_ts,
        period.to_ts,
    )

    df = pd.DataFrame([dict(r) for r in rows])
    if df.empty:
        # Toujours renvoyer un DF avec colonnes cohérentes pour export
        return pd.DataFrame(
            columns=[
                "symbol",
                "trade_count",
                "wins",
                "losses",
                "net_profit",
                "gross_profit",
                "gross_loss",
                "last_trade_at",
            ]
        )

    df["period_type"] = period.period_type
    df["period_start"] = period.period_start.isoformat()
    df["timeframe"] = timeframe
    df["updated_at"] = _utc_now().isoformat()
    return df


def _supabase_headers(service_role_key: str) -> dict:
    # PostgREST: apikey + Authorization Bearer
    return {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "application/json",
    }


def _supabase_select_trade_feedback(
    supabase_url: str, service_role_key: str, period: Period, timeout_s: int = 20
) -> pd.DataFrame:
    """
    Lit trade_feedback via PostgREST.
    Nécessite une clé service_role (ou des policies RLS adaptées).
    """
    base = supabase_url.rstrip("/")
    endpoint = f"{base}/rest/v1/trade_feedback"

    # IMPORTANT: encoder correctement le '+' de l'offset timezone (sinon il devient un espace).
    # On se base sur close_time (UTC) pour être cohérent avec MT5 "trade clôturé".
    params = [
        ("select", "symbol,profit,is_win,close_time"),
        ("close_time", f"gte.{period.from_ts.isoformat()}"),
        ("close_time", f"lte.{period.to_ts.isoformat()}"),
    ]
    r = requests.get(
        endpoint,
        params=params,
        headers=_supabase_headers(service_role_key),
        timeout=timeout_s,
    )
    if r.status_code != 200:
        raise RuntimeError(f"Supabase GET trade_feedback failed: HTTP {r.status_code} - {r.text[:200]}")

    data = r.json()
    df = pd.DataFrame(data)
    if df.empty:
        return pd.DataFrame(columns=["symbol", "profit", "is_win", "close_time"])
    return df


def _supabase_upsert_symbol_trade_stats(
    supabase_url: str, service_role_key: str, rows: list[dict], timeout_s: int = 20
) -> None:
    base = supabase_url.rstrip("/")
    endpoint = f"{base}/rest/v1/symbol_trade_stats"

    headers = _supabase_headers(service_role_key)
    headers["Prefer"] = "resolution=merge-duplicates,return=minimal"

    r = requests.post(endpoint, headers=headers, json=rows, timeout=timeout_s)
    if r.status_code not in (200, 201, 204):
        raise RuntimeError(f"Supabase UPSERT symbol_trade_stats failed: HTTP {r.status_code} - {r.text[:200]}")


async def _upsert_stats(conn: asyncpg.Connection, df: pd.DataFrame) -> int:
    if df.empty:
        return 0

    # On upsert ligne par ligne: simple et robuste
    count = 0
    for row in df.to_dict(orient="records"):
        await conn.execute(
            """
            INSERT INTO symbol_trade_stats (
                symbol, period_type, period_start, timeframe,
                trade_count, wins, losses,
                net_profit, gross_profit, gross_loss,
                last_trade_at, updated_at
            )
            VALUES (
                $1, $2, $3::date, $4,
                $5, $6, $7,
                $8, $9, $10,
                $11, now()
            )
            ON CONFLICT (symbol, period_type, period_start, timeframe)
            DO UPDATE SET
                trade_count = EXCLUDED.trade_count,
                wins = EXCLUDED.wins,
                losses = EXCLUDED.losses,
                net_profit = EXCLUDED.net_profit,
                gross_profit = EXCLUDED.gross_profit,
                gross_loss = EXCLUDED.gross_loss,
                last_trade_at = EXCLUDED.last_trade_at,
                updated_at = now()
            """,
            row["symbol"],
            row["period_type"],
            row["period_start"],
            row["timeframe"],
            int(row.get("trade_count", 0) or 0),
            int(row.get("wins", 0) or 0),
            int(row.get("losses", 0) or 0),
            float(row.get("net_profit", 0) or 0),
            float(row.get("gross_profit", 0) or 0),
            float(row.get("gross_loss", 0) or 0),
            row.get("last_trade_at"),
        )
        count += 1
    return count


async def _ensure_tables(conn: asyncpg.Connection) -> None:
    # Crée la table si la migration n'a pas encore été appliquée
    await conn.execute(
        """
        CREATE TABLE IF NOT EXISTS symbol_trade_stats (
          symbol text NOT NULL,
          period_type text NOT NULL CHECK (period_type IN ('day','month')),
          period_start date NOT NULL,
          timeframe text NOT NULL DEFAULT 'M1',

          trade_count integer NOT NULL DEFAULT 0,
          wins integer NOT NULL DEFAULT 0,
          losses integer NOT NULL DEFAULT 0,
          net_profit numeric(14, 2) NOT NULL DEFAULT 0,
          gross_profit numeric(14, 2) NOT NULL DEFAULT 0,
          gross_loss numeric(14, 2) NOT NULL DEFAULT 0,

          last_trade_at timestamptz NULL,
          created_at timestamptz NOT NULL DEFAULT now(),
          updated_at timestamptz NOT NULL DEFAULT now(),

          CONSTRAINT symbol_trade_stats_pkey PRIMARY KEY (symbol, period_type, period_start, timeframe)
        );

        CREATE INDEX IF NOT EXISTS idx_symbol_trade_stats_period
          ON symbol_trade_stats (period_type, period_start DESC, symbol);
        """
    )


def _export_excel(daily: pd.DataFrame, monthly: pd.DataFrame, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
        daily.to_excel(writer, sheet_name="Daily", index=False)
        monthly.to_excel(writer, sheet_name="Monthly", index=False)


def _aggregate_from_trade_feedback_df(trades: pd.DataFrame, period: Period, timeframe: str = "M1") -> pd.DataFrame:
    if trades.empty:
        return pd.DataFrame(
            columns=[
                "symbol",
                "trade_count",
                "wins",
                "losses",
                "net_profit",
                "gross_profit",
                "gross_loss",
                "last_trade_at",
                "period_type",
                "period_start",
                "timeframe",
                "updated_at",
            ]
        )

    # Normalisation types
    trades = trades.copy()
    trades["profit"] = pd.to_numeric(trades["profit"], errors="coerce").fillna(0.0)
    # is_win peut être absent ou incohérent; on aligne les stats sur la réalité MT5: profit > 0 / < 0
    if "is_win" in trades.columns:
        # tolérer bool, string, int
        trades["is_win"] = trades["is_win"].apply(lambda v: bool(v) if v is not None else False)
    else:
        trades["is_win"] = False

    g = trades.groupby("symbol", dropna=True)
    trade_count = g.size().astype(int)
    # Définition cohérente avec MT5: un win = profit > 0, une loss = profit < 0
    wins = g["profit"].apply(lambda s: int((s > 0).sum()))
    losses = g["profit"].apply(lambda s: int((s < 0).sum()))
    out = pd.DataFrame(
        {
            "symbol": trade_count.index,
            "trade_count": trade_count.values,
            "wins": wins.values,
            "losses": losses.values,
            "net_profit": g["profit"].sum().values,
            "gross_profit": g["profit"].apply(lambda s: s[s > 0].sum()).values,
            "gross_loss": g["profit"].apply(lambda s: (-s[s < 0]).sum()).values,
        }
    )
    # last_trade_at (max close_time si dispo, sinon created_at)
    if "close_time" in trades.columns:
        out["last_trade_at"] = g["close_time"].max().values
    elif "created_at" in trades.columns:
        out["last_trade_at"] = g["created_at"].max().values
    else:
        out["last_trade_at"] = None

    out["period_type"] = period.period_type
    out["period_start"] = period.period_start.isoformat()
    out["timeframe"] = timeframe
    out["updated_at"] = _utc_now().isoformat()
    return out


async def main() -> None:
    # Charge automatiquement .env (et variantes) si présents, sans exposer les secrets en ligne de commande
    load_dotenv()

    def _safe_load(path: str) -> None:
        try:
            load_dotenv(path, override=False, encoding="utf-8")
        except UnicodeDecodeError:
            load_dotenv(path, override=False, encoding="latin-1")

    _safe_load(".env.supabase")
    _safe_load(".env.supabase.test")

    db_url = os.getenv("DATABASE_URL")
    supabase_url = os.getenv("SUPABASE_URL") or ""
    supabase_service_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SUPABASE_SERVICE_KEY")
        or ""
    )

    if not db_url and (not supabase_url or not supabase_service_key):
        raise SystemExit(
            "Aucune configuration DB trouvée. Définissez DATABASE_URL (Postgres) ou SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY."
        )

    now = _utc_now()
    daily_period = _day_period(now)
    monthly_period = _month_period(now)

    daily: pd.DataFrame
    monthly: pd.DataFrame

    used_mode = "supabase_api"
    up1 = up2 = 0

    if db_url:
        used_mode = "postgres"
        # Diagnostic minimal sans exposer le mot de passe
        parsed = urlparse(db_url)
        safe_user = parsed.username or "?"
        safe_host = parsed.hostname or "?"
        safe_port = parsed.port or "?"
        safe_db = (parsed.path or "").lstrip("/") or "?"
        conn = None
        try:
            conn = await asyncpg.connect(db_url)
            await _ensure_tables(conn)
            daily = await _fetch_stats(conn, daily_period)
            monthly = await _fetch_stats(conn, monthly_period)
            up1 = await _upsert_stats(conn, daily)
            up2 = await _upsert_stats(conn, monthly)
        except Exception as e:
            print(f"WARN: mode Postgres indisponible ({safe_user}@{safe_host}:{safe_port}/{safe_db}) -> fallback Supabase API.")
            print(f"      {type(e).__name__}: {e}")
            used_mode = "supabase_api"
        finally:
            if conn:
                await conn.close()

    if used_mode == "supabase_api":
        if not supabase_url or not supabase_service_key:
            raise SystemExit("Fallback Supabase API impossible: SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY manquant.")

        # Lire trade_feedback via PostgREST puis agréger
        trades_day = _supabase_select_trade_feedback(supabase_url, supabase_service_key, daily_period)
        trades_month = _supabase_select_trade_feedback(supabase_url, supabase_service_key, monthly_period)
        daily = _aggregate_from_trade_feedback_df(trades_day, daily_period)
        monthly = _aggregate_from_trade_feedback_df(trades_month, monthly_period)

        # Upsert via PostgREST (la table doit exister côté DB)
        rows_daily = daily.to_dict(orient="records")
        rows_monthly = monthly.to_dict(orient="records")
        try:
            if rows_daily:
                _supabase_upsert_symbol_trade_stats(supabase_url, supabase_service_key, rows_daily)
                up1 = len(rows_daily)
            if rows_monthly:
                _supabase_upsert_symbol_trade_stats(supabase_url, supabase_service_key, rows_monthly)
                up2 = len(rows_monthly)
        except Exception as ex:
            # Ne pas bloquer l'export Excel si la table n'existe pas encore côté Supabase.
            print("WARN: Upsert Supabase échoué (la table symbol_trade_stats existe-t-elle ?).")
            print("      Appliquez la migration: supabase/migrations/20260317_symbol_trade_stats.sql")
            print(f"      {type(ex).__name__}: {ex}")

    ts = now.strftime("%Y-%m-%d_%H%M")
    out = Path("exports") / f"symbol_trade_stats_{ts}.xlsx"
    _export_excel(daily, monthly, out)

    print(f"OK: mode={used_mode} | upsert daily={up1} rows, monthly={up2} rows")
    print(f"OK: Excel export: {out}")


if __name__ == "__main__":
    import asyncio

    asyncio.run(main())

