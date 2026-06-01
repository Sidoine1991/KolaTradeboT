#!/usr/bin/env python3
"""
Crée les tables ML manquantes dans AWS RDS
- prediction_outcomes
- symbol_prediction_score_daily
"""
import psycopg2

DB = dict(
    host="trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com",
    port=5432,
    dbname="postgres",
    user="dbadmin",
    password="REMOVED_DB_PASSWORD",
    sslmode="require",
    connect_timeout=10
)

def run(conn, label, sql):
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()
        print(f"  [OK] {label}")
    except Exception as e:
        conn.rollback()
        msg = str(e).split("\n")[0]
        if "already exists" in msg or "duplicate" in msg.lower():
            print(f"  [--] {label} (déjà présent)")
        else:
            print(f"  [ERR] {label}: {msg}")
            raise

def main():
    print("Connexion AWS RDS...")
    conn = psycopg2.connect(**DB)
    conn.autocommit = False
    print(f"  Connecté: {conn.server_version}\n")

    print("=== Création tables ML manquantes ===\n")

    # --- prediction_outcomes ---
    print("1. prediction_outcomes")
    run(conn, "CREATE prediction_outcomes", """
CREATE TABLE IF NOT EXISTS prediction_outcomes (
    run_id              TEXT NOT NULL,
    step                INTEGER NOT NULL,
    symbol              TEXT NOT NULL,
    timeframe           TEXT NOT NULL,
    direction_pred      TEXT,                   -- UP, DOWN, CONSOLIDATE
    direction_actual    TEXT,                   -- UP, DOWN, CONSOLIDATE (après N bougies)
    confidence          NUMERIC(5,4),           -- 0..1 confiance du modèle
    is_correct          BOOLEAN,                -- direction_pred = direction_actual
    entry_price         NUMERIC(14,6),
    exit_price          NUMERIC(14,6),
    profit_pips         NUMERIC(10,2),
    duration_bars       INTEGER,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    evaluated_at        TIMESTAMPTZ,
    PRIMARY KEY (run_id, step)
);
""")

    run(conn, "idx_po_symbol_evaluated",
        "CREATE INDEX IF NOT EXISTS idx_po_symbol_evaluated "
        "ON prediction_outcomes (symbol, evaluated_at DESC) "
        "WHERE evaluated_at IS NOT NULL;")

    run(conn, "idx_po_run_id",
        "CREATE INDEX IF NOT EXISTS idx_po_run_id "
        "ON prediction_outcomes (run_id, created_at DESC);")

    # --- symbol_prediction_score_daily ---
    print("\n2. symbol_prediction_score_daily")
    run(conn, "CREATE symbol_prediction_score_daily", """
CREATE TABLE IF NOT EXISTS symbol_prediction_score_daily (
    symbol              TEXT NOT NULL,
    timeframe           TEXT NOT NULL,
    day                 DATE NOT NULL,
    total_predictions   INTEGER DEFAULT 0,
    correct_predictions INTEGER DEFAULT 0,
    accuracy_pct        NUMERIC(5,2),           -- 0-100 (correct/total * 100)
    avg_confidence      NUMERIC(5,4),           -- moyenne confiance
    avg_profit_pips     NUMERIC(10,2),
    winning_trades      INTEGER DEFAULT 0,
    losing_trades       INTEGER DEFAULT 0,
    win_rate_pct        NUMERIC(5,2),
    net_pips            NUMERIC(12,2),
    best_prediction_pct NUMERIC(5,4),
    worst_prediction_pct NUMERIC(5,4),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (symbol, timeframe, day)
);
""")

    run(conn, "idx_spsd_symbol_day",
        "CREATE INDEX IF NOT EXISTS idx_spsd_symbol_day "
        "ON symbol_prediction_score_daily (symbol, day DESC);")

    run(conn, "idx_spsd_accuracy",
        "CREATE INDEX IF NOT EXISTS idx_spsd_accuracy "
        "ON symbol_prediction_score_daily (accuracy_pct DESC, day DESC);")

    # --- View: latest scores par symbole ---
    run(conn, "CREATE VIEW v_latest_prediction_scores", """
CREATE OR REPLACE VIEW v_latest_prediction_scores AS
SELECT DISTINCT ON (symbol, timeframe)
    symbol,
    timeframe,
    day,
    accuracy_pct,
    win_rate_pct,
    avg_confidence,
    total_predictions,
    updated_at
FROM symbol_prediction_score_daily
ORDER BY symbol, timeframe, day DESC;
""")

    # --- View: accuracy trend ---
    run(conn, "CREATE VIEW v_prediction_accuracy_trend", """
CREATE OR REPLACE VIEW v_prediction_accuracy_trend AS
SELECT
    symbol,
    timeframe,
    day,
    accuracy_pct,
    total_predictions,
    AVG(accuracy_pct) OVER (
        PARTITION BY symbol, timeframe
        ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS accuracy_7day_ma,
    LAG(accuracy_pct) OVER (
        PARTITION BY symbol, timeframe
        ORDER BY day
    ) AS accuracy_prev_day
FROM symbol_prediction_score_daily
ORDER BY symbol, timeframe, day DESC;
""")

    # --- Verification ---
    print("\n=== Vérification ===")
    with conn.cursor() as cur:
        cur.execute("""
            SELECT tablename FROM pg_tables
            WHERE schemaname='public' AND tablename IN ('prediction_outcomes', 'symbol_prediction_score_daily')
            ORDER BY tablename;
        """)
        tables = [t[0] for t in cur.fetchall()]
        print(f"  Tables créées ({len(tables)}):")
        for t in tables:
            print(f"    - {t}")

    conn.close()
    print("\nMigration ML terminée avec succès!")

if __name__ == "__main__":
    main()
