# 🔐 TIMEFRAME LOCK FIX — Stabilisation MT5 Desktop

## Problème Identifié

**Sur TradingView Desktop (.exe):** Le timeframe bascule involontairement pendant l'exécution de l'EA.

**Impact:**
- EAs perdent leurs données synchronisées
- Indicateurs calculés deviennent invalides
- Les ordres ne se déclenchent pas (logique brisée)
- Les signaux sont ignorés

**Sur TradingView Navigator:** Pas de problème (timeframe stable)

---

## Solution Appliquée

### TradeManager.mq5

**Ligne 609-620:** Ajout du verrouillage de timeframe dans OnTick()

```mql5
void OnTick()
{
   // 🔐 TIMEFRAME LOCK — Protéger contre les changements manuels
   if(Period() != g_lockedTimeframe)
   {
      PrintFormat("[TradeManager] ⚠️ TIMEFRAME CHANGED: %s → %s — REVERT TO M1",
                  (g_lockedTimeframe==PERIOD_M1?"M1":"UNKNOWN"),
                  (Period()==PERIOD_M1?"M1":Period()==PERIOD_M5?"M5":"OTHER"));
      ChartSetInteger(0, CHART_TIMEFRAME, PERIOD_M1);  // Force back to M1
      g_lockedTimeframe = PERIOD_M1;
   }
   // ... reste du code
}
```

**Comportement:**
- ✅ Détecte si le timeframe change
- ✅ Force le retour au timeframe configuré (M1)
- ✅ Log un message d'alerte
- ✅ Continue l'exécution normalement

### SpikeRiderEA.mq5

**Ligne 3287-3302:** Même verrouillage

```mql5
void OnTick()
{
   // 🔐 TIMEFRAME LOCK — Protéger contre les changements manuels
   if(Period() != InpTF)
   {
      PrintFormat("[SpikeRider] ⚠️ TIMEFRAME CHANGED: %s → %s — REVERT TO M1",
                  (InpTF==PERIOD_M1?"M1":"UNKNOWN"),
                  (Period()==PERIOD_M1?"M1":Period()==PERIOD_M5?"M5":"OTHER"));
      ChartSetInteger(0, CHART_TIMEFRAME, InpTF);  // Force back to configured TF
   }
   // ... reste du code
}
```

---

## Vérification dans MT5

Après recompilation et rechargement des EAs, vérifier:

### 1. Logs (F2)
Chercher les messages:
```
[TradeManager] ⚠️ TIMEFRAME CHANGED: M1 → M5 — REVERT TO M1
[SpikeRider] ⚠️ TIMEFRAME CHANGED: M1 → H1 — REVERT TO M1
```

Si aucun message → Bon! Timeframe stable.

### 2. Test manuel
- Lancer MT5 avec EAs chargés
- Cliquer sur un timeframe différent (ex: M5, H1)
- Vérifier dans les logs si le message de revert s'affiche
- Confirmer que le chart retourne automatiquement à M1

### 3. Signal normal
```
[GOM-Auto] ✅ XAUUSD: GOM=PERFECT BUY — SIGNAL ACCEPTÉ ✅
[SpikeRider] ✅ SPIKE DETECTED Z-Score=1.8
```

Si les logs continuent sans "TIMEFRAME CHANGED" → Fix fonctionnel ✅

---

## Impact sur Performance

**Overhead:** Minimal
- ✅ Check `if(Period() != g_lockedTimeframe)` = O(1)
- ✅ Exécuté une fois par tick
- ✅ `ChartSetInteger()` seulement si changement détecté

**Avantage:**
- ✅ EAs restent synchronisés
- ✅ Signaux ne sont plus perdus
- ✅ Ordres se déclenchent correctement

---

## Déploiement

### Étapes:
1. **Recompiler** les 2 EAs:
   ```bash
   D:\Dev\TradBOT\START_TRADING_SYSTEM.bat
   ```

2. **Relancer MT5** avec les EAs attachés

3. **Vérifier** les logs (F2) pour aucun "TIMEFRAME CHANGED"

4. **Confirmer** que trades s'ouvrent normalement

### Rollback (si besoin):
Supprimer les 10 lignes ajoutées dans OnTick() et recompiler.

---

## TradingView Desktop (MCP Kola) — cause racine M15/H1

Les analyses SMC (`smcQuickAnalysis`, `multiTimeframeAnalysis`) passaient le graphique en **M15/H1/H4** puis restauraient parfois le mauvais TF. Le poller GOM lit alors des bougies incohérentes.

**Correctif appliqué** (`tradingview-mcp_kola`) :
- `chart.restoreTradBotTimeframe()` — ramène **M1** après chaque analyse (sauf `TRADBOT_TV_PRESERVE_TF=1`)
- `gom_verdict_poller.py` — `node tv timeframe 1` avant/après chaque poll
- `scripts/tv_analyze_cli.mjs` — restauration M1 en `finally`

## Fichiers Modifiés

- ✅ `D:\Dev\TradBOT\TradeManager.mq5` (Line 609-620)
- ✅ `D:\Dev\TradBOT\SpikeRiderEA.mq5` (Line 3287-3302)
- ✅ `D:\Dev\Depot Github\tradingview-mcp_kola\src\core\chart.js`
- ✅ `D:\Dev\Depot Github\tradingview-mcp_kola\src\core\tradbot_analysis.js`
- ✅ `D:\Dev\TradBOT\Python\gom_verdict_poller.py`
- ✅ `D:\Dev\TradBOT\scripts\tv_analyze_cli.mjs`

---

## Status

🟢 **Fix Appliqué** — Prêt à compiler et tester
🟡 **Test Requis** — Déployer via START_TRADING_SYSTEM.bat
🔴 **En Attente** — Feedback sur stabilité après recompilation

---

**Date:** 2026-05-29 09:15 UTC  
**Issue:** Timeframe bascule involontaire MT5 Desktop  
**Solution:** Verrouillage automatique + revert forcé
