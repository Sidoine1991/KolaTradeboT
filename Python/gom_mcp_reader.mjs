
// gom_mcp_reader.mjs — lit study values + quote via CDP TradingView
// Appelé par gom_verdict_poller.py via subprocess

import { createMcpClient } from '@tradingview-kola/mcp';

async function main() {
  const client = await createMcpClient();
  try {
    const [studies, quote] = await Promise.all([
      client.callTool('data_get_study_values', {}),
      client.callTool('quote_get', {}),
    ]);
    console.log(JSON.stringify({ studies, quote, success: true }));
  } catch(e) {
    console.log(JSON.stringify({ success: false, error: String(e) }));
  } finally {
    await client.close();
  }
}
main();
