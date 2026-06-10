# État courant — TradBOT

Dernière session : 2026-06-07

## Points ouverts
- [ ] Coller GOM_KOLA_script.pine corrigé dans TradingView (ta.highest/ta.lowest hors barstate.islast)
- [ ] Reset inputs EA dans MT5 → "Reset to Defaults" pour activer InpPollSymbols 40+ symboles
- [ ] Supprimer vieil ordre XAUUSD du store (DELETE /pending-order?symbol=XAUUSD)
- [ ] BTCUSD entry parfois None (yfinance timezone) — surveiller les prochains runs

## Prochaines actions
1. Lancer pipeline production : run_pipeline.bat
2. Vérifier 1 seule position par signal dans MT5 (anti-duplication actif)
3. Lancer gom_verdict_poller.py pour alimenter le dashboard MT5

## État technique (2026-06-07)
- TradeManager : v3.24 compilé et actif
- Pipeline : pipeline_with_approval.py (run_pipeline.bat / run_pipeline_auto.bat)
- AI server : verrou anti-duplication actif (status executing)
- Tâche planifiée : TradBOT_Pipeline_Horaire → run_pipeline_auto.bat --auto (toutes les heures à :07)
- Lot : 0.20 Boom/Crash, 0.01 Forex/Crypto
