"""Regression checks for the non-blocking EA GOM fast-poll path."""

import ast
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "ai_server.py"


def _functions(source: str) -> dict[str, ast.FunctionDef | ast.AsyncFunctionDef]:
    tree = ast.parse(source)
    return {
        node.name: node
        for node in ast.walk(tree)
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
    }


def test_poller_fast_path_requires_a_timestamped_fresh_verdict():
    functions = _functions(SERVER.read_text(encoding="utf-8"))
    route = ast.unparse(functions["get_gom_verdict"])

    assert "age is not None and age <= max_age" in route
    assert "poller_store_empty_or_stale" in route


def test_poller_fast_path_skips_sync_enrichment_and_queues_projection():
    functions = _functions(SERVER.read_text(encoding="utf-8"))
    route = ast.unparse(functions["get_gom_verdict"])
    builder = ast.unparse(functions["_build_gom_mt5_payload"])
    cognition = ast.unparse(functions["_gom_cached_or_schedule_cognition"])

    assert "_build_gom_mt5_payload(dict(stored), enrich=False)" in route
    assert "_gom_cached_or_schedule_cognition(sym, dict(stored))" in route
    assert "if sym and enrich:" in builder
    assert "_enrich_cognition_forecast" in builder
    assert "_cog_short_executor.submit(refresh_short)" in cognition
    assert "_cog_path_executor.submit(refresh)" in cognition


def test_candle_uploads_do_not_compete_with_gom_dashboard_workers():
    source = SERVER.read_text(encoding="utf-8")
    functions = _functions(source)
    route = ast.unparse(functions["mt5_upload_candles"])
    pipeline = (ROOT / "mt5" / "modules" / "SMC_GOM_Pipeline.mqh").read_text(
        encoding="utf-8"
    )
    uploader = (ROOT / "mt5" / "modules" / "MT5_Candles_Uploader.mqh").read_text(
        encoding="utf-8"
    )

    assert "_mt5_upload_executor, _process_upload" in route
    assert "effectiveInterval = MathMax(GOMPollIntervalSec, 5)" in pipeline
    assert "terminal_error=" in uploader
    assert "response=" in uploader
