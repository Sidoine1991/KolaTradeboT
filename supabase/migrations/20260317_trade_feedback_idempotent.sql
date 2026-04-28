-- Rendre trade_feedback idempotent (upload batch MT5)
-- Ajoute mt5_deal_id + position_id et un index unique pour upsert

ALTER TABLE IF EXISTS trade_feedback
  ADD COLUMN IF NOT EXISTS mt5_deal_id bigint,
  ADD COLUMN IF NOT EXISTS position_id bigint,
  ADD COLUMN IF NOT EXISTS magic bigint;

-- Unicité par deal ticket MT5 (si présent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'ux_trade_feedback_mt5_deal_id'
  ) THEN
    CREATE UNIQUE INDEX ux_trade_feedback_mt5_deal_id ON trade_feedback (mt5_deal_id) WHERE mt5_deal_id IS NOT NULL;
  END IF;
END $$;

