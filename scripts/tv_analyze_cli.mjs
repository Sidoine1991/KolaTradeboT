#!/usr/bin/env node
/**
 * CLI — analyse TradingView via MCP Kola (CDP port 9222 requis).
 * Usage: node tv_analyze_cli.mjs [SYMBOL] [smc|spike|both]
 * Sortie: JSON stdout
 */
import { pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dir = dirname(fileURLToPath(import.meta.url));
const TV_ROOT = process.env.TV_MCP_ROOT || join(__dir, '..', '..', 'Depot Github', 'tradingview-mcp_kola');
const modPath = pathToFileURL(join(TV_ROOT, 'src', 'core', 'tradbot_analysis.js')).href;

const symbolArg = process.argv[2] || null;
const mode = (process.argv[3] || 'both').toLowerCase();

const { smcQuickAnalysis, spikeAnalysis } = await import(modPath);

const out = {
  success: false,
  symbol: symbolArg,
  mode,
  analyzed_at: new Date().toISOString(),
  smc: null,
  spike: null,
  error: null,
};

try {
  const sym = symbolArg || undefined;
  const isSynth = symbolArg && /boom|crash/i.test(symbolArg);

  if (mode === 'smc' || mode === 'both') {
    out.smc = await smcQuickAnalysis({ symbol: sym });
  }
  if ((mode === 'spike' || mode === 'both') && (isSynth || !symbolArg)) {
    out.spike = await spikeAnalysis({ symbol: sym, lookback: 20 });
  }

  out.success = Boolean(
    (out.smc && out.smc.success) ||
    (out.spike && out.spike.success)
  );
  if (!out.symbol) {
    out.symbol = out.smc?.symbol || out.spike?.symbol || null;
  }
} catch (err) {
  out.error = err.message || String(err);
  out.success = false;
}

console.log(JSON.stringify(out, null, 2));
process.exit(out.success ? 0 : 1);
