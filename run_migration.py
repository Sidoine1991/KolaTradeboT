#!/usr/bin/env python3
"""
Migration AWS RDS — TradBOT SMC
Applique les optimisations sur les tables existantes et crée les nouvelles tables.
Idempotent : peut être relancé sans risque.
"""
import psycopg2
import sys

DB = dict(
    host="trading-db.cq9suk2wcwxh.us-east-1.rds.amazonaws.com",
    port=5432, dbname="postgres", user="dbadmin",
    password="REMOVED_DB_PASSWORD", sslmode="require", connect_timeout=10
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

def main():
    print("Connexion AWS RDS...")
    conn = psycopg2.connect(**DB)
    conn.autocommit = False
    print(f"  Connecté: {conn.server_version}\n")

    # =========================================================================
    # 1. EXTENSIONS
    # =========================================================================
    print("=== 1. Extensions ===")
    run(conn, "pgcrypto", "CREATE EXTENSION IF NOT EXISTS pgcrypto;")

    # =========================================================================
    # 2. TRIGGER updated_at (fonction partagée)
    # =========================================================================
    print("\n=== 2. Trigger updated_at ===")
    run(conn, "fonction _set_updated_at", """
CREATE OR REPLACE FUNCTION _set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;
""")
    run(conn, "helper _attach_updated_at_trigger", """
CREATE OR REPLACE FUNCTION _attach_updated_at_trigger(tbl text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_' || tbl || '_updated_at'
    ) THEN
        EXECUTE format(
            'CREATE TRIGGER trg_%I_updated_at
             BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION _set_updated_at()',
            tbl, tbl
        );
    END IF;
END;
$$;
""")

    # =========================================================================
    # 3. COLONNES MANQUANTES SUR LES TABLES EXISTANTES
    # =========================================================================
    print("\n=== 3. Colonnes manquantes ===")

    # trade_feedback
    tf_cols = [
        ("mt5_deal_id",     "BIGINT"),
        ("position_id",     "BIGINT"),
        ("magic",           "INTEGER"),
        ("timeframe_entry", "TEXT"),
        ("verdict_label",   "TEXT"),
        ("setup_score",     "NUMERIC(6,2)"),
        ("spike_detected",  "BOOLEAN DEFAULT FALSE"),
        ("duration_min",    "INTEGER"),
        ("updated_at",      "TIMESTAMPTZ DEFAULT now()"),
    ]
    for col, typ in tf_cols:
        run(conn, f"trade_feedback.{col}",
            f"ALTER TABLE trade_feedback ADD COLUMN IF NOT EXISTS {col} {typ};")

    # model_metrics
    mm_cols = [
        ("samples_train",   "INTEGER"),
        ("samples_test",    "INTEGER"),
        ("auc_roc",         "NUMERIC(6,4)"),
        ("updated_at",      "TIMESTAMPTZ DEFAULT now()"),
    ]
    for col, typ in mm_cols:
        run(conn, f"model_metrics.{col}",
            f"ALTER TABLE model_metrics ADD COLUMN IF NOT EXISTS {col} {typ};")

    # symbol_calibration
    sc_cols = [
        ("avg_profit",       "NUMERIC(10,4)"),
        ("best_hour_utc",    "SMALLINT"),
        ("updated_at",       "TIMESTAMPTZ DEFAULT now()"),
    ]
    for col, typ in sc_cols:
        run(conn, f"symbol_calibration.{col}",
            f"ALTER TABLE symbol_calibration ADD COLUMN IF NOT EXISTS {col} {typ};")

    # trades
    tr_cols = [
        ("verdict_label",    "TEXT"),
        ("ia_direction",     "TEXT"),
        ("setup_score",      "NUMERIC(6,2)"),
        ("spike_captured",   "BOOLEAN DEFAULT FALSE"),
        ("updated_at",       "TIMESTAMPTZ DEFAULT now()"),
    ]
    for col, typ in tr_cols:
        run(conn, f"trades.{col}",
            f"ALTER TABLE trades ADD COLUMN IF NOT EXISTS {col} {typ};")

    # stair_detections
    sd_cols = [
        ("direction",        "TEXT"),
        ("spike_prob",       "NUMERIC(5,4)"),
        ("atr_at_detection", "NUMERIC(14,6)"),
        ("updated_at",       "TIMESTAMPTZ DEFAULT now()"),
    ]
    for col, typ in sd_cols:
        run(conn, f"stair_detections.{col}",
            f"ALTER TABLE stair_detections ADD COLUMN IF NOT EXISTS {col} {typ};")

    # market_data_snapshots
    mds_cols = [
        ("verdict_label",    "TEXT"),
        ("verdict_conf_pct", "NUMERIC(5,2)"),
        ("top3_rank",        "SMALLINT"),
    ]
    for col, typ in mds_cols:
        run(conn, f"market_data_snapshots.{col}",
            f"ALTER TABLE market_data_snapshots ADD COLUMN IF NOT EXISTS {col} {typ};")

    # =========================================================================
    # 4. TRIGGERS updated_at sur les tables qui en ont besoin
    # =========================================================================
    print("\n=== 4. Triggers updated_at ===")
    for tbl in ["trade_feedback", "model_metrics", "symbol_calibration",
                "trades", "stair_detections", "adaptive_strategies"]:
        run(conn, f"trigger {tbl}",
            f"SELECT _attach_updated_at_trigger('{tbl}');")

    # =========================================================================
    # 5. INDEX MANQUANTS SUR TABLES EXISTANTES
    # =========================================================================
    print("\n=== 5. Index ===")

    indexes = [
        # trade_feedback — requête hot : win-rate par symbole + timeframe
        ("idx_tf_symbol_tf_close",
         "CREATE INDEX IF NOT EXISTS idx_tf_symbol_tf_close "
         "ON trade_feedback (symbol, timeframe, close_time DESC);"),
        ("idx_tf_is_win",
         "CREATE INDEX IF NOT EXISTS idx_tf_is_win "
         "ON trade_feedback (is_win) WHERE is_win IS NOT NULL;"),
        ("idx_tf_side",
         "CREATE INDEX IF NOT EXISTS idx_tf_side "
         "ON trade_feedback (symbol, side);"),
        ("idx_tf_verdict",
         "CREATE INDEX IF NOT EXISTS idx_tf_verdict "
         "ON trade_feedback (symbol, verdict_label) WHERE verdict_label IS NOT NULL;"),

        # model_metrics — ORDER BY training_date DESC LIMIT 1
        ("idx_mm_symbol_tf_date",
         "CREATE INDEX IF NOT EXISTS idx_mm_symbol_tf_date "
         "ON model_metrics (symbol, timeframe, training_date DESC);"),

        # symbol_calibration — upsert unique
        ("ux_sc_symbol_tf",
         "CREATE UNIQUE INDEX IF NOT EXISTS ux_sc_symbol_tf "
         "ON symbol_calibration (symbol, timeframe);"),

        # trades
        ("idx_trades_symbol_close",
         "CREATE INDEX IF NOT EXISTS idx_trades_symbol_close "
         "ON trades (symbol, close_time DESC);"),
        ("idx_trades_magic",
         "CREATE INDEX IF NOT EXISTS idx_trades_magic "
         "ON trades (magic_number);"),

        # market_data_snapshots — unlabelled rows
        ("idx_mds_unlabelled",
         "CREATE INDEX IF NOT EXISTS idx_mds_unlabelled "
         "ON market_data_snapshots (symbol, timestamp DESC) "
         "WHERE direction_5min = 0 AND price_5min_later IS NULL;"),
        ("idx_mds_symbol_ts",
         "CREATE INDEX IF NOT EXISTS idx_mds_symbol_ts "
         "ON market_data_snapshots (symbol, timestamp DESC);"),

        # ml_predictions — unevaluated
        ("idx_mlp_unevaluated",
         "CREATE INDEX IF NOT EXISTS idx_mlp_unevaluated "
         "ON ml_predictions (created_at DESC) WHERE evaluated_at IS NULL;"),
        ("idx_mlp_model",
         "CREATE INDEX IF NOT EXISTS idx_mlp_model "
         "ON ml_predictions (model_name, created_at DESC);"),

        # stair_detections — win-rate aggregate
        ("idx_sd_closed_trades",
         "CREATE INDEX IF NOT EXISTS idx_sd_closed_trades "
         "ON stair_detections (symbol, outcome) "
         "WHERE outcome IN ('win','loss');"),

        # predictions
        ("idx_pred_symbol_created",
         "CREATE INDEX IF NOT EXISTS idx_pred_symbol_created "
         "ON predictions (symbol, created_at DESC);"),

        # ml_training_runs
        ("idx_mtr_symbol_status",
         "CREATE INDEX IF NOT EXISTS idx_mtr_symbol_status "
         "ON ml_training_runs (symbol, status, completed_at DESC);"),

        # correction_predictions
        ("idx_cp_symbol_ts",
         "CREATE INDEX IF NOT EXISTS idx_cp_symbol_ts "
         "ON correction_predictions (symbol, timestamp DESC);"),
    ]

    for name, sql in indexes:
        run(conn, name, sql)

    # =========================================================================
    # 6. NOUVELLES TABLES
    # =========================================================================
    print("\n=== 6. Nouvelles tables ===")

    # --- symbol_setup_scores ---
    run(conn, "CREATE symbol_setup_scores", """
CREATE TABLE IF NOT EXISTS symbol_setup_scores (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol          TEXT NOT NULL,
    score           NUMERIC(6,2) NOT NULL,         -- 0-100 score composite
    win_rate        NUMERIC(5,2),                  -- historique 200 bougies (%)
    setup_score_live NUMERIC(6,2),                 -- ComputeSetupScoreValue live
    rank_position   SMALLINT,                      -- 1=Gold, 2=Silver, 3=Bronze
    in_top3         BOOLEAN DEFAULT FALSE,
    direction       TEXT,                          -- BUY | SELL | BOTH
    total_setups    INTEGER DEFAULT 0,
    buy_wr          NUMERIC(5,2),
    sell_wr         NUMERIC(5,2),
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
""")
    run(conn, "idx_sss_symbol_rec",
        "CREATE INDEX IF NOT EXISTS idx_sss_symbol_rec "
        "ON symbol_setup_scores (symbol, recorded_at DESC);")
    run(conn, "idx_sss_top3",
        "CREATE INDEX IF NOT EXISTS idx_sss_top3 "
        "ON symbol_setup_scores (rank_position, recorded_at DESC) WHERE in_top3 = TRUE;")
    run(conn, "view v_latest_setup_scores", """
CREATE OR REPLACE VIEW v_latest_setup_scores AS
SELECT DISTINCT ON (symbol)
    symbol, score, win_rate, rank_position, in_top3, direction,
    buy_wr, sell_wr, total_setups, recorded_at
FROM symbol_setup_scores
ORDER BY symbol, recorded_at DESC;
""")

    # --- spike_detection_events ---
    run(conn, "CREATE spike_detection_events", """
CREATE TABLE IF NOT EXISTS spike_detection_events (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol           TEXT NOT NULL,
    direction        TEXT NOT NULL CHECK (direction IN ('BUY','SELL')),
    atr_multiplier   NUMERIC(6,3) NOT NULL,        -- range / ATR(14) au moment du spike
    candle_range     NUMERIC(14,6),
    atr_value        NUMERIC(14,6),
    entry_price      NUMERIC(14,6),
    exit_price       NUMERIC(14,6),
    profit_usd       NUMERIC(10,4),
    profit_captured  BOOLEAN DEFAULT FALSE,        -- TRUE si position fermée post-spike
    close_reason     TEXT,                         -- "POST-SPIKE"|"TP"|"SL"|"TIMEOUT"
    hour_utc         SMALLINT,
    duration_sec     INTEGER,
    verdict_label    TEXT,
    detected_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at        TIMESTAMPTZ
);
""")
    run(conn, "idx_sde_symbol_hour",
        "CREATE INDEX IF NOT EXISTS idx_sde_symbol_hour "
        "ON spike_detection_events (symbol, hour_utc);")
    run(conn, "idx_sde_detected",
        "CREATE INDEX IF NOT EXISTS idx_sde_detected "
        "ON spike_detection_events (symbol, detected_at DESC);")
    run(conn, "idx_sde_unclosed",
        "CREATE INDEX IF NOT EXISTS idx_sde_unclosed "
        "ON spike_detection_events (symbol, detected_at DESC) WHERE closed_at IS NULL;")
    run(conn, "view v_spike_quality_by_hour", """
CREATE OR REPLACE VIEW v_spike_quality_by_hour AS
SELECT
    symbol,
    direction,
    hour_utc,
    COUNT(*)                                        AS total_spikes,
    ROUND(AVG(atr_multiplier)::NUMERIC, 3)          AS avg_atr_mult,
    ROUND(SUM(CASE WHEN profit_captured THEN 1 ELSE 0 END)::NUMERIC
          / NULLIF(COUNT(*),0) * 100, 1)            AS capture_rate_pct,
    ROUND(AVG(CASE WHEN profit_captured THEN profit_usd END)::NUMERIC, 4) AS avg_profit_captured
FROM spike_detection_events
GROUP BY symbol, direction, hour_utc;
""")

    # --- verdict_entry_quality ---
    run(conn, "CREATE verdict_entry_quality", """
CREATE TABLE IF NOT EXISTS verdict_entry_quality (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol           TEXT NOT NULL,
    verdict_label    TEXT NOT NULL,                -- "GOOD BUY", "PERFECT SELL", etc.
    verdict_conf_pct NUMERIC(5,2),                 -- finalConfPct 0-100
    ia_direction     TEXT,                         -- BUY | SELL | HOLD
    prediction_dir   TEXT,                         -- UP | DOWN | CONSOLIDATE
    trend_dir        TEXT,                         -- UPTREND | DOWNTREND | SIDEWAYS
    entry_tf         TEXT,                         -- M1 | M5 | M5_LINE | GOM_M5 | MKT
    entry_price      NUMERIC(14,6),
    sl_price         NUMERIC(14,6),
    tp_price         NUMERIC(14,6),
    setup_score      NUMERIC(6,2),
    in_top3          BOOLEAN DEFAULT FALSE,
    -- Outcome (backfillé à la fermeture)
    result           TEXT DEFAULT 'OPEN'
                         CHECK (result IN ('OPEN','WIN','LOSS','BREAKEVEN','CANCELLED')),
    pips             NUMERIC(10,2),
    profit_usd       NUMERIC(10,4),
    duration_min     INTEGER,
    close_reason     TEXT,
    trade_feedback_id BIGINT,                      -- FK vers trade_feedback.id
    opened_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at        TIMESTAMPTZ,
    updated_at       TIMESTAMPTZ DEFAULT now()
);
""")
    run(conn, "trigger verdict_entry_quality",
        "SELECT _attach_updated_at_trigger('verdict_entry_quality');")
    run(conn, "idx_veq_symbol_opened",
        "CREATE INDEX IF NOT EXISTS idx_veq_symbol_opened "
        "ON verdict_entry_quality (symbol, opened_at DESC);")
    run(conn, "idx_veq_open_trades",
        "CREATE INDEX IF NOT EXISTS idx_veq_open_trades "
        "ON verdict_entry_quality (symbol, opened_at DESC) WHERE result = 'OPEN';")
    run(conn, "idx_veq_verdict",
        "CREATE INDEX IF NOT EXISTS idx_veq_verdict "
        "ON verdict_entry_quality (verdict_label, symbol);")
    run(conn, "view v_verdict_win_rate", """
CREATE OR REPLACE VIEW v_verdict_win_rate AS
SELECT
    symbol,
    verdict_label,
    COUNT(*)                                             AS total,
    SUM(CASE WHEN result = 'WIN'  THEN 1 ELSE 0 END)   AS wins,
    SUM(CASE WHEN result = 'LOSS' THEN 1 ELSE 0 END)   AS losses,
    ROUND(SUM(CASE WHEN result = 'WIN' THEN 1 ELSE 0 END)::NUMERIC
          / NULLIF(COUNT(*) FILTER (WHERE result <> 'OPEN'), 0) * 100, 1) AS win_rate_pct,
    ROUND(AVG(profit_usd)::NUMERIC, 4)                  AS avg_profit,
    ROUND(AVG(duration_min)::NUMERIC, 1)                AS avg_duration_min
FROM verdict_entry_quality
WHERE result <> 'OPEN'
GROUP BY symbol, verdict_label;
""")

    # --- ai_decisions_log ---
    run(conn, "CREATE ai_decisions_log", """
CREATE TABLE IF NOT EXISTS ai_decisions_log (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol           TEXT NOT NULL,
    timeframe        TEXT,
    decision         TEXT NOT NULL CHECK (decision IN ('BUY','SELL','HOLD','WAIT')),
    confidence       NUMERIC(5,4),                 -- 0..1
    verdict_label    TEXT,
    verdict_conf_pct NUMERIC(5,2),
    ia_direction     TEXT,
    prediction_dir   TEXT,
    trend_dir        TEXT,
    spike_prob       NUMERIC(5,4),
    setup_score      NUMERIC(6,2),
    ml_score         NUMERIC(6,4),
    in_top3          BOOLEAN DEFAULT FALSE,
    request_json     JSONB,
    response_json    JSONB,
    -- Outcome backfillé
    outcome_result   TEXT CHECK (outcome_result IN ('WIN','LOSS','BREAKEVEN','SKIPPED',NULL)),
    outcome_profit   NUMERIC(10,4),
    trade_feedback_id BIGINT,
    decided_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    outcome_at       TIMESTAMPTZ
);
""")
    run(conn, "idx_adl_symbol_decided",
        "CREATE INDEX IF NOT EXISTS idx_adl_symbol_decided "
        "ON ai_decisions_log (symbol, decided_at DESC);")
    run(conn, "idx_adl_decision",
        "CREATE INDEX IF NOT EXISTS idx_adl_decision "
        "ON ai_decisions_log (decision, decided_at DESC);")
    run(conn, "idx_adl_no_outcome",
        "CREATE INDEX IF NOT EXISTS idx_adl_no_outcome "
        "ON ai_decisions_log (symbol, decided_at DESC) WHERE outcome_result IS NULL;")

    # --- symbol_trade_stats (vue agrégée pour dashboard) ---
    run(conn, "CREATE symbol_trade_stats", """
CREATE TABLE IF NOT EXISTS symbol_trade_stats (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    symbol          TEXT NOT NULL,
    period_date     DATE NOT NULL DEFAULT CURRENT_DATE,
    direction       TEXT CHECK (direction IN ('BUY','SELL','BOTH')),
    wins            INTEGER DEFAULT 0,
    losses          INTEGER DEFAULT 0,
    total_trades    INTEGER DEFAULT 0,
    win_rate        NUMERIC(5,2),
    net_profit      NUMERIC(12,4),
    avg_profit      NUMERIC(10,4),
    max_profit      NUMERIC(10,4),
    max_loss        NUMERIC(10,4),
    avg_duration_min NUMERIC(8,2),
    updated_at      TIMESTAMPTZ DEFAULT now()
);
""")
    run(conn, "ux_sts_symbol_date_dir",
        "CREATE UNIQUE INDEX IF NOT EXISTS ux_sts_symbol_date_dir "
        "ON symbol_trade_stats (symbol, period_date, direction);")
    run(conn, "trigger symbol_trade_stats",
        "SELECT _attach_updated_at_trigger('symbol_trade_stats');")

    # =========================================================================
    # 7. VERIFICATION FINALE
    # =========================================================================
    print("\n=== 7. Vérification finale ===")
    with conn.cursor() as cur:
        cur.execute("""
            SELECT tablename FROM pg_tables
            WHERE schemaname='public' ORDER BY tablename;
        """)
        tables = [t[0] for t in cur.fetchall()]
        print(f"  Tables dans la DB ({len(tables)}):")
        for t in tables:
            print(f"    - {t}")

        cur.execute("""
            SELECT indexname, tablename FROM pg_indexes
            WHERE schemaname='public' AND indexname LIKE 'idx_%'
            ORDER BY tablename, indexname;
        """)
        idxs = cur.fetchall()
        print(f"\n  Index custom ({len(idxs)}):")
        for ix, tbl in idxs:
            print(f"    [{tbl}] {ix}")

        cur.execute("""
            SELECT table_name, view_definition IS NOT NULL AS has_def
            FROM information_schema.views
            WHERE table_schema = 'public'
            ORDER BY table_name;
        """)
        views = cur.fetchall()
        print(f"\n  Vues ({len(views)}):")
        for v, _ in views:
            print(f"    - {v}")

    conn.close()
    print("\nMigration terminee avec succes.")

if __name__ == "__main__":
    main()
