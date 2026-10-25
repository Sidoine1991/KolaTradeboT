"""Source-level regression checks for the MT5 EA's final GOM entry guards."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STUBS = ROOT / "mt5" / "modules" / "SMC_Stubs.mqh"
PIPELINE = ROOT / "mt5" / "modules" / "SMC_GOM_Pipeline.mqh"
FUTURE_PATH = ROOT / "mt5" / "modules" / "SMC_FuturePath.mqh"
GOM_GRAPHICS = ROOT / "mt5" / "modules" / "GOM_Graphics.mqh"
EA = ROOT / "mt5" / "SMC_Universal.mq5"


def function_body(source: str, signature: str) -> str:
    start = source.index(signature)
    while True:
        closing = source.index(")", start)
        opening = source.index("{", closing)
        semicolon = source.find(";", closing)
        if semicolon == -1 or opening < semicolon:
            break
        start = source.index(signature, start + len(signature))
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"Unclosed function body: {signature}")


def test_current_wait_guard_checks_numeric_and_display_verdict():
    source = PIPELINE.read_text(encoding="utf-8")
    body = function_body(source, "bool SMC_GOMCurrentVerdictIsWait(")

    assert "g_smcGomVerdictNum" in body
    assert "g_smcGomVerdict" in body
    assert "marketPriceFresh" in body
    assert "forecast5mReady" in body
    assert "marketPriceAgeSec > 90.0" in body
    assert "SMCGP_GetCachedVerdictNum(resolvedSymbol)" in body
    assert "SMCGP_GetCachedVerdictStr(resolvedSymbol)" in body
    assert 'verdictNum == -999 || verdictNum == 0' in body


def test_current_market_forecast_gate_runs_after_local_overrides():
    source = PIPELINE.read_text(encoding="utf-8")
    parser = function_body(source, "void SMCGP_ParseGOMBody(")

    assert parser.index("SMCGP_ApplyCurrentMarketForecastGate(_Symbol)") < parser.index(
        "if(g_smcGomHarmonizedM1)"
    )
    assert parser.rindex("SMCGP_ApplyCurrentMarketForecastGate(_Symbol)") > parser.index(
        "SMCGP_ApplyCorrectionVerdictWait(_Symbol, serverCorrWait)"
    )
    gate = function_body(source, "void SMCGP_ApplyCurrentMarketForecastGate(")
    assert "market_price" not in gate
    assert "g_smcMarketPriceFresh" in gate
    assert "g_smcForecastHorizonMinutes == 5" in gate
    assert "g_smcGomVerdictForecastNum != 0" in gate
    assert "MathMin(MathAbs(vn), MathAbs(g_smcGomVerdictForecastNum))" in gate


def test_disconnected_cache_cannot_replace_a_current_wait():
    source = PIPELINE.read_text(encoding="utf-8")
    body = function_body(source, "void SMCGP_RestoreCachedIfDisconnected(")

    assert body.index("SMC_GOMCurrentVerdictIsWait(_Symbol)") < body.index(
        "SMCGP_GetCachedVerdictNum(_Symbol)"
    )


def test_wait_is_rejected_before_shared_order_send_bypass():
    source = STUBS.read_text(encoding="utf-8")
    body = function_body(source, "bool SafeOrderSend(")

    wait_guard = body.index("SMC_GOMCurrentVerdictIsWait(req.symbol)")
    bypass_gate = body.index("!g_smcAlignExecBypass")
    assert wait_guard < bypass_gate
    assert "ORDER_TYPE_BUY_STOP_LIMIT" in body
    assert "ORDER_TYPE_SELL_STOP_LIMIT" in body


def test_c_trade_wrappers_reject_wait_even_for_spike_override():
    source = STUBS.read_text(encoding="utf-8")
    for signature, broker_call in (
        ("bool SafeTradeBuy(", "return t.Buy("),
        ("bool SafeTradeSell(", "return t.Sell("),
    ):
        body = function_body(source, signature)
        assert body.index("SMC_GOMCurrentVerdictIsWait(symbol)") < body.index(broker_call)


def test_final_gate_rejects_wait_before_any_verdict_restore_override():
    source = EA.read_text(encoding="utf-8")
    body = function_body(source, "bool SMC_FinalOpenGate(")

    wait_guard = body.index("SMC_GOMCurrentVerdictIsWait(symbol)")
    restore = body.index("SMCGP_RestoreCachedIfDisconnected()")
    local_fallback = body.index("g_localFallbackOverrideActive")
    assert wait_guard < restore
    assert wait_guard < local_fallback


def test_final_gate_requires_fresh_aligned_server_context():
    source = EA.read_text(encoding="utf-8")
    body = function_body(source, "bool SMC_FinalOpenGate(")

    assert "g_smcMarketPriceFresh" in body
    assert "g_smcMarketPriceAgeSec <= 90.0" in body
    assert "g_smcForecast5mReady" in body
    assert "g_smcForecastHorizonMinutes == 5" in body
    assert "g_smcGomVerdictForecastNum > 0) == isBuySide" in body
    assert "g_smcGomVerdictNumServer > 0) == isBuySide" in body
    assert "!g_smcGomEntryAllowed" in body
    assert "!g_localFallbackOverrideActive" in body
    assert "!spikeHTFOverride && !spikeChainGomOverride" in body
    assert "contexte GOM non confirmé" in body


def test_m1_simple_signal_can_bypass_5m_wait_only_with_m1_confirmation():
    pipeline = PIPELINE.read_text(encoding="utf-8")
    current_wait = function_body(pipeline, "bool SMC_GOMCurrentVerdictIsWait(")
    assert "if(!forecast5mReady || forecast5mHorizon != 5 || forecast5mVn == 0)" in current_wait
    assert "if(MathAbs(forecast5mVn) >= 2)" in current_wait
    assert "return !(m1ScalpSimpleAllowed && MathAbs(verdictNum) == 1);" in current_wait

    scalp = function_body(pipeline, "bool SMCGP_M1ScalpSimpleAllowsDirection(")
    assert "g_smcM1ScalpSimpleAllowed" in scalp
    assert "g_smcGomEntryAllowed" in scalp
    assert "g_smcMarketPriceAgeSec > 90.0" in scalp
    assert "g_smcTfM1DirLive" in scalp

    m1m5 = function_body(EA.read_text(encoding="utf-8"), "bool SMC_M1M5GomAlignGateOK(")
    assert "SMCGP_M1ScalpSimpleAllowsDirection(symbol, dirSign)" in m1m5

    server = (ROOT / "ai_server.py").read_text(encoding="utf-8")
    assert "or bool(out.get(\"m1_scalp_simple_allowed\"))" in server
    assert "SIMPLE requires confirmed M1 structure" in server
    assert "fresh_price+M1_1b3b_aligned" in server


def test_missing_projection_payload_retains_recent_forecast_temporarily():
    pipeline = PIPELINE.read_text(encoding="utf-8")
    parse = function_body(pipeline, "void SMCGP_ParseCognitionArrays(")
    assert '"cog_fc_close"' in parse
    assert '"pred_path_mid"' in parse
    assert "g_smcCogPathLastPayloadTime" in parse
    assert "ageSec > 90" in parse
    assert "return;" in parse[: parse.index('SMCGP_ParseJsonArrayKey(body, "pred_path_mid"')]

    future_path = FUTURE_PATH.read_text(encoding="utf-8")
    draw = function_body(future_path, "void SMCFP_DrawFromGlobals(")
    assert "!g_smcCogPathPayloadFresh" in draw
    assert "SMCFP_MarkStale(ageSec)" in draw
    assert "ageSec <= 90" in draw
    assert "Projection precedente" in future_path


def test_pattern_override_cannot_promote_wait_without_live_market_confirmation():
    source = EA.read_text(encoding="utf-8")
    start = source.index("int adjustedGOM = SMC_PGI_AdjustGOMVerdict(")
    end = source.index("if(overrideAllowed && adjustedGOM != originalGOMNum)", start)
    override = source[start:end]

    assert "originalGOMNum != 0" in override
    assert "!g_smcGomCorrectionWait" in override
    assert "!g_smcGomHardDollarCorrection" in override
    assert "g_smcGomConnected" in override
    assert 'g_smcGomSource != "CACHE_STALE_POLL"' in override
    assert 'g_smcGomSource != "CACHE_STALE_POLL_FORCED_WAIT"' in override
    assert "g_smcMarketPriceFresh" in override
    assert "g_smcForecast5mReady" in override
    assert "g_smcForecastHorizonMinutes == 5" in override
    assert "g_smcGomVerdictForecastNum != 0" in override
    assert "adjustedGOM = originalGOMNum;" in override


def test_paused_good_verdict_is_displayed_without_overwriting_trade_wait():
    pipeline = PIPELINE.read_text(encoding="utf-8")
    ea = EA.read_text(encoding="utf-8")

    display_num = function_body(pipeline, "int SMCGP_DisplayVerdictNum(")
    display_text = function_body(pipeline, "string SMCGP_DisplayVerdictText(")
    assert "g_smcGomVerdictNum != 0" in display_num
    assert "MathAbs(serverVn) < 2" in display_num
    assert "g_smcLastGOMPoll" in display_num
    assert "CACHE_STALE_POLL" in display_num
    assert 'return "WAIT";' in display_text
    assert '" | ENTRY PAUSED"' in display_text
    assert "SMC_SpikeChainGomEntryOverrideAllowed(" in display_text
    assert "SMC_ForceGomGridVerdictSync" not in ea
    parse = function_body(pipeline, "void SMCGP_ParseGOMBody(")
    assert "bool hasServerVn" in parse
    assert "else if(hasServerVn)" in parse
    assert 'g_smcGomVerdictServer = (srvVn == 0) ? "WAIT"' in parse
    assert "if(stalePayload)" in parse


def test_future_forecast_does_not_overlay_wait_on_a_fresh_good_verdict():
    graphics = GOM_GRAPHICS.read_text(encoding="utf-8")
    body = function_body(graphics, "void GOMG_DrawFutureZone(")
    display_branch = body.index("int displayGomDir = SMCGP_DisplayVerdictNum();")
    wait_label = body.index('dirTxt += " | GOM WAIT: NO ENTRY";')
    assert display_branch < wait_label
    assert "dirTxt += \" | GOM \" + SMCGP_DisplayVerdictText();" in body[display_branch:wait_label]

def test_future_zone_redraws_when_the_gom_verdict_or_entry_gate_changes():
    source = EA.read_text(encoding="utf-8")
    body = function_body(source, "void OnTick(")
    assert "displayGomVn != s_lastDisplayGom" in body
    assert "g_smcGomEntryAllowed != s_lastEntryAllowed" in body
    redraw = body.index("if(bbChanged || gomChanged)")
    assert body.index("GOMG_DrawFutureZone(", redraw) > redraw


def test_preflight_gates_and_diagnostic_order_cannot_bypass_wait():
    source = EA.read_text(encoding="utf-8")
    for signature, later_operation in (
        ("bool CanPlaceOrderByGOM(", "SMCGP_RestoreCachedIfDisconnected()"),
        ("bool CanPlaceMarketOrder(", "SMCGP_RestoreCachedIfDisconnected()"),
    ):
        body = function_body(source, signature)
        assert body.index("SMC_GOMCurrentVerdictIsWait(symbol)") < body.index(later_operation)

    diagnostic = function_body(source, "void SMC_PlaceDiagnosticTestOrder()")
    assert diagnostic.index("SMC_FinalOpenGate(DiagnosticTestSymbol, ORDER_TYPE_BUY)") < diagnostic.index(
        "OrderSend(request, result)"
    )


def test_hard_loss_cutoff_uses_the_effective_configured_cap():
    stubs = STUBS.read_text(encoding="utf-8")
    cap = function_body(stubs, "double SMC_HardMaxLossUSD()")
    assert "MathMin(cap, MaxLossDollars)" in cap
    assert "MathMin(cap, UniversalMaxLossUSD)" in cap
    assert "MathMin(cap, MaxLossPerTradeDollars)" in cap

    ea = EA.read_text(encoding="utf-8")
    cutoff = function_body(ea, "bool SMC_EnforceHardLossCutoff()")
    assert "double hardLossCap = SMC_HardMaxLossUSD()" in cutoff
    assert "if(loss > -hardLossCap) continue;" in cutoff
    sizing = function_body(ea, "double SMC_GetDynamicMaxLossUSD()")
    assert "double effectiveCap = SMC_HardMaxLossUSD()" in sizing
    assert "cap = MathMin(cap, effectiveCap)" in sizing


def test_market_sl_cannot_be_widened_past_the_loss_cap():
    pipeline = PIPELINE.read_text(encoding="utf-8")
    prepare = function_body(pipeline, "bool SMCGP_PrepareMarketStops(")
    cap = prepare.index("double maxSlDist = (capUSD / (tickValCap * lotUse)) * tickSizeCap;")
    assert "SMC_HardMaxLossUSD()" in prepare
    assert "if(maxSlDist < minD)" in prepare
    assert "slDist = MathMin(maxSlDist, slDist * 1.20);" in prepare
    assert "if(-estimatedProfit > capUSD * 1.001)" in prepare
    assert "slDist = MathMax(slDist, pip * 10.0);" not in prepare[cap:]


def test_pending_and_dynamic_dollar_guards_use_a_broker_side_cap():
    stubs = STUBS.read_text(encoding="utf-8")
    safe_send = function_body(stubs, "bool SafeOrderSend(")
    assert "req.action == TRADE_ACTION_PENDING" in safe_send
    assert "ORDRE EN ATTENTE REJETÉ" in safe_send

    dynamic_sl = (ROOT / "mt5" / "modules" / "SMC_DynamicDollarSL.mqh").read_text(
        encoding="utf-8"
    )
    manage = function_body(dynamic_sl, "void SMC_ManageDynamicDollarSL()")
    assert "double maxLossUSD = SMC_HardMaxLossUSD()" in manage
    assert "MathMin(maxLossUSD, DynSL_MaxLossUSD)" in manage


def test_spike_chain_good_override_requires_fresh_native_aligned_chain():
    source = EA.read_text(encoding="utf-8")
    override = function_body(
        source, "bool SMC_SpikeChainGomEntryOverrideAllowed("
    )

    assert "SMC_IsSpikeStyleSymbol(symbol)" in override
    assert "IsBoomLikeSymbol(symbol) && dirSign > 0" in override
    assert "IsCrashLikeSymbol(symbol) && dirSign < 0" in override
    assert "MathAbs(serverVn) < 2" in override
    assert "pollAgeSec > 90" in override
    assert "priceAgeSec > 90.0" in override
    assert "SPIKE_STATE_CHAIN_ACTIVE" in override
    assert "g_spikeChainStrongBars < 2" in override
    assert "SMC_TfDirMatchesSign(dirSign, m1Dir)" in override
    assert "SMC_TfDirMatchesSign(dirSign, g_smcTfM5Dir)" in override
    assert "SMC_TfDirMatchesSign(dirSign, g_smcTfM15Dir)" in override
    assert "CountPositionsForSymbol(symbol) > 0" in override
    assert "OrderGetString(ORDER_SYMBOL) == symbol" in override
    assert "g_smcGomHardDollarCorrection" in override
    assert "g_smcGomServerCorrWait" in override
    assert "g_smcM1EntryBlocked" in override
    assert "g_smcPaInCorrection && !g_smcCorrEntrySafe" in override


def test_spike_chain_override_only_accepts_weak_or_missing_forecast_reasons():
    pipeline = PIPELINE.read_text(encoding="utf-8")
    parse = function_body(pipeline, "void SMCGP_ParseGOMBody(")
    assert 'SMCGP_JsonString(body, "entry_block_reason")' in parse
    assert 'SMCGP_JsonString(body, "market_forecast_gate_reason")' in parse

    source = EA.read_text(encoding="utf-8")
    reasons = function_body(source, "bool SMC_SpikeChainGomReasonIsOverridable(")
    assert '"5m_forecast_unavailable"' in reasons
    assert '"5m_forecast_unconfirmed"' in reasons
    assert '"weak_opposing_5m_m1_structure"' in reasons
    assert '"weak_opposing_5m_with_native_spike_htf"' in reasons
    assert '"5m_forecast_opposes_reactive_verdict"' not in reasons
    override = function_body(
        source, "bool SMC_SpikeChainGomEntryOverrideAllowed("
    )
    assert "g_smcGomCorrectionReason" in override
    assert "forecastHasNoConfirmation" in override
    assert 'entryBlockReason == "wait"' in override
    assert '"5m_forecast_strongly_opposes_verdict"' not in override


def test_unified_market_path_uses_guarded_spike_chain_good_exception():
    pipeline = PIPELINE.read_text(encoding="utf-8")
    current_wait = function_body(pipeline, "bool SMC_GOMCurrentVerdictIsWait(")
    assert "SMC_SpikeChainGomEntryOverrideAllowed(" in current_wait

    source = EA.read_text(encoding="utf-8")
    unified = function_body(source, "void SMC_UnifiedGOMEntryOnTick()")
    assert "spikeChainGoodException" in unified
    assert "if(g_smcGomVerdictNum == 0 && !spikeChainGoodException)" in unified
    assert "MathAbs(g_smcGomVerdictNum) < MinGOMVerdictNumAbs" in unified

    market = function_body(source, "bool CanPlaceMarketOrder(")
    assert "SMC_SpikeChainGomEntryOverrideAllowed(symbol, dirSign)" in market
    gom_gate = function_body(source, "bool CanPlaceOrderByGOM(")
    assert "vn = g_smcGomVerdictNumServer;" in gom_gate

    final_gate = function_body(source, "bool SMC_FinalOpenGate(")
    assert "bool spikeChainGomOverride =" in final_gate
    assert "!spikeHTFOverride && !spikeChainGomOverride" in final_gate
    assert "!spikeHTFOverride && !spikeChainGomOverride)" in final_gate
    assert "SMC_GOMLiveQuoteAllowsEntry" in final_gate
    assert "SMC_LowCapitalAllowsSymbol" in final_gate
    assert "SMC_SpreadAllowsEntry" in final_gate
    assert "ACCOUNT_MARGIN_FREE" in final_gate

    graphics = GOM_GRAPHICS.read_text(encoding="utf-8")
    exec_reason = function_body(graphics, "string GOMG_ExecBlockReason(")
    assert "SMC_SpikeChainGomEntryOverrideAllowed(_Symbol, dirSign)" in exec_reason
    display_text = function_body(
        PIPELINE.read_text(encoding="utf-8"), "string SMCGP_DisplayVerdictText("
    )
    assert "SMC_SpikeChainGomEntryOverrideAllowed(" in display_text
