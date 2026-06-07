# TradeManager - Fix Lots Énormes & Règles Boom/Crash

**Date:** 2026-06-07  
**Problème:** TradeManager exécute des trades avec des lots énormes au lieu du lot minimal

## ✅ Corrections Appliquées

### 1. Protection Boom/Crash (CRITIQUE)
**Ligne 3456-3471** - Ajout validation stricte dans `IngestPendingOrderForSymbol`:

```mql5
// 🚫 RÈGLE CRITIQUE: SELL interdit sur Boom, BUY interdit sur Crash
if(StringFind(sym, "Boom") >= 0 && action == "SELL")
{
   Print(StringFormat("[TradeManager] 🚫 %s: SELL INTERDIT sur Boom — signal REJETÉ", sym));
   SendNotification(StringFormat("🚫 TradBOT: SELL bloqué sur %s (Boom=BUY only)", sym));
   return;
}
if(StringFind(sym, "Crash") >= 0 && action == "BUY")
{
   Print(StringFormat("[TradeManager] 🚫 %s: BUY INTERDIT sur Crash — signal REJETÉ", sym));
   SendNotification(StringFormat("🚫 TradBOT: BUY bloqué sur %s (Crash=SELL only)", sym));
   return;
}
```

**Règles:**
- ❌ **SELL INTERDIT sur Boom** (Boom 300, 500, 1000 = BUY uniquement)
- ❌ **BUY INTERDIT sur Crash** (Crash 300, 500, 1000 = SELL uniquement)

### 2. Lot Minimum Déjà Protégé ✅
Tous les endroits d'ouverture de trades utilisent **DÉJÀ** `SYMBOL_VOLUME_MIN`:

| Fonction | Ligne | Status |
|----------|-------|--------|
| `IngestPendingOrderForSymbol` | 3445 | ✅ Déjà protégé |
| `TryTVSetupPendingEntry` | 1410 | ✅ Déjà protégé |
| `TryTVPreSpikeMarketEntry` | 1479 | ✅ Déjà protégé |
| `TryReEntryOnEMA` | 2666 | ✅ Déjà protégé |
| `DRV_PlaceEntry` (Deriv) | 3122 | ✅ Déjà protégé |
| `DuplicateMCPPosition` | 3791 | ✅ Déjà protégé |
| `MonitorManualDuplicates` | 4119 | ✅ Déjà protégé |
| `CheckGOMAutoEntry` | 4880 | ✅ Déjà protégé |
| `CheckGOMReEntry` | 4994 | ✅ Déjà protégé |

**Code standard utilisé partout:**
```mql5
// 🔧 FORCER LOT MINIMUM BROKER (ignorer lot serveur pour éviter survolume)
double lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
```

### 3. Duplication Boom/Crash Déjà Bloquée ✅
**Ligne 1724-1727** - `CanDuplicateOnSymbol`:
```mql5
if(IsBoomOrCrashSymbol(sym))
{
   why = "duplication interdite sur Boom/Crash";
   return false;
}
```

## 🔍 Diagnostic Requis

Si des lots énormes sont quand même exécutés:

### A. Vérifier l'origine des ordres
1. Ouvrir **Expert Journal** dans MT5
2. Chercher les logs `[TradeManager] ✅ MCP AUTO` avec `lot=X.XX`
3. Si `lot > VOLUME_MIN` → Le serveur AI envoie des lots incorrects

### B. Vérifier SYMBOL_VOLUME_MIN
```mql5
// Dans OnInit() ou script test
Print("SYMBOL_VOLUME_MIN = ", SymbolInfoDouble("Boom 500 Index", SYMBOL_VOLUME_MIN));
Print("SYMBOL_VOLUME_MIN = ", SymbolInfoDouble("Crash 1000 Index", SYMBOL_VOLUME_MIN));
Print("SYMBOL_VOLUME_MIN = ", SymbolInfoDouble("ETHUSD", SYMBOL_VOLUME_MIN));
```

**Valeurs attendues:**
- Boom/Crash: 0.1 - 1.0
- ETHUSD: 0.01
- Forex majeurs: 0.01

### C. Vérifier le serveur AI
Le serveur AI (`autonomous_pipeline.py`) calcule des lots dans `ComputeLotSize()`.  
**IMPORTANT:** TradeManager **IGNORE** ces lots et force `SYMBOL_VOLUME_MIN`.

Si problème persiste → vérifier qu'aucune modification manuelle n'a retiré le fix.

## 📊 Tests à Faire

### Test 1: Validation Boom/Crash
```python
# Envoyer signal SELL sur Boom via bridge
python Python/tradbot_bridge.py --symbol "Boom 500 Index" --action SELL --entry 15000
# ✅ Attendu: Signal REJETÉ avec message "SELL INTERDIT sur Boom"
```

### Test 2: Validation Crash
```python
# Envoyer signal BUY sur Crash via bridge
python Python/tradbot_bridge.py --symbol "Crash 1000 Index" --action BUY --entry 5000
# ✅ Attendu: Signal REJETÉ avec message "BUY INTERDIT sur Crash"
```

### Test 3: Lot Minimum
```python
# Envoyer signal valide avec lot énorme dans JSON
curl -X POST http://127.0.0.1:8000/pending-order \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "ETHUSD",
    "action": "BUY",
    "entry_price": 3500,
    "stop_loss": 3450,
    "take_profit": 3600,
    "lot": 100.0
  }'
# ✅ Attendu: Trade ouvert avec lot = SYMBOL_VOLUME_MIN (ignore 100.0)
```

## 🎯 Résumé

| Problème | Status | Action |
|----------|--------|--------|
| Lots énormes | ✅ DÉJÀ FIX | Tous les trades forcent VOLUME_MIN |
| SELL sur Boom | ✅ FIX AJOUTÉ | Validation stricte ligne 3456-3471 |
| BUY sur Crash | ✅ FIX AJOUTÉ | Validation stricte ligne 3456-3471 |
| Duplication Boom/Crash | ✅ DÉJÀ PROTÉGÉ | Ligne 1724-1727 |

## 📝 Prochaines Étapes

1. **Compiler TradeManager.mq5** dans MetaEditor
2. **Attacher l'EA** sur charts: Boom 500, Crash 1000, ETHUSD
3. **Lancer pipeline:** `python Python/autonomous_pipeline.py --skip-ta`
4. **Vérifier logs MT5:** Aucun trade avec lot > VOLUME_MIN
5. **Vérifier rejets:** Logs `SELL INTERDIT sur Boom` et `BUY INTERDIT sur Crash`

---

**⚠️ IMPORTANT:**
- Ne jamais modifier les lignes qui forcent `SYMBOL_VOLUME_MIN`
- Ne jamais retirer la validation Boom/Crash (lignes 3456-3471)
- Toujours tester sur compte démo avant production
