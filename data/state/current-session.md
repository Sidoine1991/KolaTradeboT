# Etat courant — TradBOT

Derniere session : 2026-05-20

## Points ouverts
- Indices synthetiques Deriv sans donnees OHLC yfinance — contexte technique injecte depuis ai_server comme palliatif
- Tous les changements sont non commites — committer avant la prochaine session

## Prochaines actions
1. git add -A && git commit -m "feat: TradingAgents bridge + Word reports + EA stabilisation"
2. Tester cycle complet EURUSD : bridge -> ordre limit -> execution MT5
3. Recompiler SMC_Universal.mq5 (MetaEditor F7)

## Architecture bridge (resume)
.\bridge.bat --symbol "EURUSD"
  -> fetch_tradbot_context() : indicateurs depuis ai_server
  -> TradingAgentsGraph.propagate() : analyse LLM multi-agents
  -> save_report_word() : rapport .docx dans reports/
  -> POST /tradingagents/manual-report : signal pondere /decision
  -> POST /pending-order : ordre persistant (pending_orders.json)
  -> EA poll GET /pending-order -> place l ordre

## Config LLM active
- Provider : bedrock (profil AWS default) avec failover -> nvidia_nim (free-claude-code)
- Deep/Quick : us.anthropic.claude-sonnet-4-5-20250929-v1:0
- Failover NIM : nvidia_nim/z-ai/glm-5.1 (MODEL_FAILOVER dans free-claude-code)

## SMC_Universal (2026-05-21)
- Pipeline spike Boom/Crash intégré (`EnableBoomCrashSpikePipeline`)
- Forex plafond lot 0.01 (`SMC_GetBrokerMinLotVolume`)
- SL/TP spike via ATR (`UseBoomCrashSpikeAtrStops`)
- **Ordres LIMIT désactivés par défaut** (`EnableLimitOrderPlacement=false`) — entrées marché uniquement ; annulation auto des pending LIMIT à l'init et toutes les 30s
- **Stratégie Divergence Deriv** : `python/divergence_strategy.py` + fusion dans `ai_server.py` `/decision` ; EA envoie `recent_candles` (220 M1) et exécute `CheckAndExecuteDivergenceMarketEntry` si signal Div
