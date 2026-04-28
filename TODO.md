# Fix Plan for SMC_Universal.mq5 Compilation Errors

## Steps
- [x] Replace PlaceLimitOrdersOnTrendEntry with PlaceSMCPredictionLimitOrders at line 524
- [x] Replace PlaceLimitOrdersOnTrendEntry with PlaceSMCPredictionLimitOrders at line 688
- [x] Remove local CTrade declaration + MagicNumber/AllowedDeviation in ExecuteSMCPredictionArrowTrade (lines 846-848)
- [x] Remove local CTrade declaration + MagicNumber/AllowedDeviation in PlaceSMCPredictionLimitOrders (lines 889-891)
- [x] Verify compilation succeeds

