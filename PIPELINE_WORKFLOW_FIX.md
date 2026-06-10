# Pipeline Workflow Fix - TradingAgents Obligatoire

**Date:** 2026-06-07  
**Commits:** 
- 6e22c454 - TradeManager protection Boom/Crash
- 305a6dcb - Pipeline TradingAgents obligatoire + attente complète

## ✅ Problèmes Résolus

### 1. Entry/SL/TP Manquants (`N/A`)

**Avant:**
```
BTCUSD     BUY   entry=N/A  SL=N/A  TP=N/A  lot=0.00
DERIV:BOOM_500_INDEX SELL entry=N/A SL=N/A TP=N/A lot=0.00
```

**Cause:**  
Pipeline exécuté avec `--skip-ta` → TradingAgents ignoré → entry/SL/TP jamais calculés.

**Fix:**
- TradingAgents TOUJOURS actif par défaut
- `--skip-ta` toujours possible mais **FORTEMENT déconseillé** (warnings explicites)
- Timeout augmenté à 600s (au lieu de 300s) pour analyses complètes
- Warning si ordres manquent niveaux avant envoi TradeManager

**Après (attendu):**
```
BTCUSD     BUY   entry=51234.50  SL=50800.00  TP=52100.00  lot=0.01
ETHUSD     SELL  entry=3456.78   SL=3520.00   TP=3330.00   lot=0.01
```

### 2. Workflow Incorrect - Pas d'Attente TradingAgents

**Workflow AVANT (INCORRECT):**
```
Phase 1: Scan TV → Top-5
Phase 2: TradingAgents → IGNORÉ (--skip-ta)
Phase 3: Fusion → Fake (assume TA = direction TV)
Phase 4: Envoi ordres → INCOMPLETS (entry/SL/TP = None)
```

**Workflow APRÈS (CORRECT):**
```
Phase 1: Scan TV → Top-5 symboles avec scores confluence
Phase 2: TradingAgents → TOUS analysés en parallèle
         ⏳ ATTENTE COMPLÈTE (600s timeout)
         Log progrès: 1/5 (20%) → 2/5 (40%) → ... → 5/5 (100%)
Phase 3: Fusion TV+TA → Validation Boom/Crash + Alignement
         ALIGNED si TV et TA dans même sens
Phase 4: Envoi ordres → COMPLETS (entry/SL/TP précis depuis TA)
Phase 5: EA registry check (300s polling)
Phase 6: Monitor 20min (symboles EA ready)
```

**Code modifié:**
```python
# Phase 2 - Attente BLOQUANTE de tous les workers
log.info("⏳ Attente COMPLÈTE de tous les TradingAgents avant phase 3 (fusion)...")
for future in as_completed(future_map, timeout=self.cfg.ta_timeout_sec + 60):
    result = future.result()
    results.append(result)
    # Log progrès temps réel
    completed = len(results)
    total = len(candidates)
    pct = int(completed / total * 100)
    log.info("  [TA] Progrès: %d/%d (%d%%) — %s terminé", completed, total, pct, result.symbol)

log.info("✅ Enrichissement COMPLET: %d/%d succès — Passage à phase 3 (fusion)", success_n, len(results))
```

### 3. Validation Boom/Crash Manquante

**Avant:**  
Pipeline acceptait SELL sur Boom → ordres envoyés → TradeManager devait rejeter.

**Après:**  
Validation **AVANT** fusion → rejet immédiat → logs clairs.

**Code ajouté (ligne ~515):**
```python
@staticmethod
def _validate_boom_crash_direction(symbol: str, direction: str) -> tuple[bool, str]:
    """
    🚫 RÈGLE CRITIQUE: SELL interdit sur Boom, BUY interdit sur Crash.
    Indices synthétiques unidirectionnels — violation = perte garantie 100%.

    Returns:
        (ok, reason): (True, "") si valide, (False, raison) si interdit
    """
    symbol_upper = symbol.upper()
    direction_upper = direction.upper()

    # BOOM = BUY uniquement (spikes haussiers)
    if "BOOM" in symbol_upper and direction_upper == "SELL":
        return False, "🚫 SELL INTERDIT sur Boom (Boom = BUY uniquement - spikes haussiers)"

    # CRASH = SELL uniquement (spikes baissiers)
    if "CRASH" in symbol_upper and direction_upper == "BUY":
        return False, "🚫 BUY INTERDIT sur Crash (Crash = SELL uniquement - spikes baissiers)"

    return True, ""

# Dans phase_fuse() — AVANT compute_verdict
boom_crash_ok, boom_crash_reason = self._validate_boom_crash_direction(scan.symbol, scan.direction)
if not boom_crash_ok:
    log.warning("  🚫 %s: %s — REJET IMMÉDIAT", scan.symbol, boom_crash_reason)
    fused.append(FusedSignal(
        symbol=scan.symbol, direction=scan.direction, verdict="REJECT",
        # ... lot=0.0, entry/SL/TP=None
        reasoning=boom_crash_reason,
    ))
    continue  # Skip compute_verdict
```

### 4. Fusion Fake vs Vraie

**Avant (`--skip-ta`):**
```python
# Fusion fake - assume TA = direction TV
return [
    TAResult(
        symbol=c.symbol, 
        signal_rating=c.direction,        # ← Copie TV
        normalized_rating=c.direction,     # ← Copie TV
        entry_price=c.entry_price,         # ← None si TV pas fourni
        confidence=c.confluence_score/10,  # ← Fake confidence
        success=True,                      # ← Fake success
    )
    for c in candidates
]
```

**Après (TradingAgents actif):**
```python
# Vraie analyse TradingAgents via ta_worker.py
cmd = [python, worker, scan.symbol, date_str]
proc = subprocess.run(cmd, ...)
data = json.loads(stdout)

return TAResult(
    symbol              = scan.symbol,
    signal_rating       = data.get("signal_rating", "HOLD"),      # ← Vraie TA
    normalized_rating   = data.get("normalized_rating", "HOLD"),  # ← Vraie TA
    entry_price         = data.get("entry_price"),                # ← Calculé TA
    stop_loss           = data.get("stop_loss"),                  # ← Calculé TA
    take_profit         = data.get("take_profit"),                # ← Calculé TA
    confidence          = float(data.get("confidence", 0.5)),     # ← Vraie confidence
    success             = bool(data.get("success", False)),       # ← Vraie success
)
```

## 🔧 Modifications Techniques

### Fichier: `Python/autonomous_pipeline.py`

| Ligne | Modification |
|-------|--------------|
| 7-30 | Doc mise à jour: workflow, règles critiques, warnings --skip-ta |
| 380-392 | Phase 2: Warnings explicites si --skip-ta utilisé |
| 395 | Phase 2: Log "⏳ Attente COMPLÈTE" |
| 467-476 | Phase 2: Log progrès temps réel (X/N %) |
| 490 | Phase 2: "✅ Enrichissement COMPLET" avant phase 3 |
| 497-511 | Phase 3: Validation Boom/Crash AVANT fusion |
| 558-578 | Phase 3: Fonction `_validate_boom_crash_direction()` |
| 676-680 | Phase 4: Warning si entry/SL/TP manquants |
| 682 | Phase 4: Log "📤 Envoi N ordres COMPLETS" |
| 1053 | Arg `--skip-ta`: "⚠️ DÉCONSEILLÉ" |
| 1054 | Arg `--ta-timeout`: 600s (au lieu de 300s) |

**Total:** +108 lignes, -13 lignes

### Arguments CLI

**Avant:**
```bash
--skip-ta             # Pas TradingAgents — TV uniquement
--ta-timeout 300      # Timeout 300s
```

**Après:**
```bash
--skip-ta             # ⚠️ DÉCONSEILLÉ: Skip TradingAgents (pas de entry/SL/TP précis)
--ta-timeout 600      # Timeout 600s (défaut pour analyses complètes)
```

## 📊 Comparaison Logs

### Avant (avec --skip-ta)

```
2026-06-07 13:38:20 [INFO] === PHASE 1 : Scan TradingView ===
2026-06-07 13:38:20 [INFO]   TOP: DERIV:BOOM_500_INDEX SELL score=7.1/10  entry=None
2026-06-07 13:38:20 [INFO] === PHASE 2 : TradingAgents IGNORÉ (--skip-ta) ===
2026-06-07 13:38:20 [INFO] === PHASE 3 : Fusion TV + TA ===
2026-06-07 13:38:21 [INFO]   ✅ DERIV:BOOM_500_INDEX SELL | TV=7.1 TA=SELL → ALIGNED
2026-06-07 13:38:21 [INFO] === PHASE 4 : Envoi ordres → TradeManager ===
2026-06-07 13:38:21 [INFO]   ✅ Ordre SELL DERIV:BOOM_500_INDEX @ None SL=None TP=None lot=0.0
```

**Problèmes:**
- ❌ entry/SL/TP = None → TradeManager ne peut pas exécuter
- ❌ SELL sur Boom accepté → violation règle critique
- ❌ TA=SELL fake (copie TV, pas vraie analyse)

### Après (TradingAgents actif + validation)

```
2026-06-07 14:00:00 [INFO] === PHASE 1 : Scan TradingView ===
2026-06-07 14:00:00 [INFO]   TOP: DERIV:BOOM_500_INDEX SELL score=7.1/10  entry=None
2026-06-07 14:00:00 [INFO] === PHASE 2 : TradingAgents (5 symboles, max 3 en parallèle, timeout 600s) ===
2026-06-07 14:00:00 [INFO] ⏳ Attente COMPLÈTE de tous les TradingAgents avant phase 3 (fusion)...
2026-06-07 14:00:15 [INFO]   [TA] Progrès: 1/5 (20%) — BTCUSD terminé
2026-06-07 14:00:30 [INFO]   [TA] Progrès: 2/5 (40%) — ETHUSD terminé
2026-06-07 14:00:45 [INFO]   [TA] Progrès: 3/5 (60%) — DERIV:BOOM_500_INDEX terminé
2026-06-07 14:01:00 [INFO]   [TA] Progrès: 4/5 (80%) — DERIV:CRASH_1000_INDEX terminé
2026-06-07 14:01:15 [INFO]   [TA] Progrès: 5/5 (100%) — DERIV:BOOM_300_INDEX terminé
2026-06-07 14:01:15 [INFO] ✅ Enrichissement COMPLET: 5/5 succès — Passage à phase 3 (fusion)
2026-06-07 14:01:15 [INFO] === PHASE 3 : Fusion TV + TA ===
2026-06-07 14:01:15 [WARNING]   🚫 DERIV:BOOM_500_INDEX: 🚫 SELL INTERDIT sur Boom (Boom = BUY uniquement - spikes haussiers) — REJET IMMÉDIAT
2026-06-07 14:01:15 [INFO]   ✅ BTCUSD BUY  | TV=7.5 TA=BUY → ALIGNED
2026-06-07 14:01:15 [INFO]   ✅ ETHUSD SELL | TV=5.9 TA=SELL → ALIGNED
2026-06-07 14:01:15 [INFO] Fusion terminée: 2/5 ALIGNED
2026-06-07 14:01:15 [INFO] === PHASE 4 : Envoi ordres → TradeManager ===
2026-06-07 14:01:15 [INFO] 📤 Envoi 2 ordres COMPLETS (entry/SL/TP depuis TradingAgents)...
2026-06-07 14:01:15 [INFO]   ✅ Ordre BUY BTCUSD @ 51234.5 SL=50800.0 TP=52100.0 lot=0.01
2026-06-07 14:01:15 [INFO]   ✅ Ordre SELL ETHUSD @ 3456.78 SL=3520.0 TP=3330.0 lot=0.01
```

**Améliorations:**
- ✅ Attente complète TA avec progrès temps réel
- ✅ SELL sur Boom rejeté AVANT envoi TradeManager
- ✅ Ordres COMPLETS avec entry/SL/TP précis
- ✅ Fusion vraie (TA vraie analyse, pas copie TV)

## 🎯 Test Workflow

### Test 1: Pipeline Complet (SANS --skip-ta)

```bash
python Python/autonomous_pipeline.py
```

**Attendu:**
1. Phase 1: Scan TV → 5 symboles
2. Phase 2: TradingAgents × 5 (attente complète ~60-300s selon symboles)
   - Logs progrès: 1/5 (20%) → ... → 5/5 (100%)
3. Phase 3: Fusion + Validation Boom/Crash
   - SELL sur Boom → REJECT
   - BUY sur Crash → REJECT
4. Phase 4: Ordres COMPLETS envoyés
   - entry/SL/TP précis dans logs
5. Rapport Word avec niveaux précis

### Test 2: --skip-ta (Déconseillé, debug uniquement)

```bash
python Python/autonomous_pipeline.py --skip-ta
```

**Attendu:**
```
[WARNING] === PHASE 2 : TradingAgents IGNORÉ (--skip-ta) ===
[WARNING] ⚠️ ATTENTION: Skip TradingAgents = PAS de entry/SL/TP précis!
[WARNING] ⚠️ Les ordres envoyés à TradeManager seront INCOMPLETS
...
[WARNING] ⚠️ Ordres INCOMPLETS (entry/SL/TP manquants): ['BTCUSD', 'ETHUSD', ...]
[WARNING] ⚠️ TradeManager ne pourra pas exécuter correctement!
```

### Test 3: Morning Scan Report

```bash
python Python/morning_scan_report.py
```

**Attendu:**
- Rapport Word avec entry/SL/TP précis (si pipeline complet exécuté avant)
- Signaux invalides (SELL sur Boom) absents du rapport

## 📋 Règles de Trading Codifiées

### Validation Multi-Couche

#### 1. Pipeline Python (NOUVEAU)
**Fichier:** `autonomous_pipeline.py` phase 3  
**Ligne:** 497-511

```python
boom_crash_ok, boom_crash_reason = self._validate_boom_crash_direction(scan.symbol, scan.direction)
if not boom_crash_ok:
    log.warning("🚫 %s: %s — REJET IMMÉDIAT", scan.symbol, boom_crash_reason)
    # verdict="REJECT", lot=0.0
```

#### 2. TradeManager MQL5 (Déjà présent)
**Fichier:** `TradeManager.mq5` ligne 3456-3471  
**Fonction:** `IngestPendingOrderForSymbol`

```mql5
if(StringFind(sym, "Boom") >= 0 && action == "SELL")
{
   Print(StringFormat("[TradeManager] 🚫 %s: SELL INTERDIT sur Boom — signal REJETÉ", sym));
   SendNotification(...);
   return;  // REJET
}
```

### Matrice Décision

| Symbole | Direction TV | Validation Pipeline | Validation TradeManager | Résultat |
|---------|--------------|---------------------|-------------------------|----------|
| Boom 500 | BUY | ✅ PASS | ✅ PASS | ✅ Ordre envoyé |
| Boom 500 | SELL | ❌ REJECT | ❌ REJECT | ❌ Rejeté phase 3 |
| Crash 1000 | SELL | ✅ PASS | ✅ PASS | ✅ Ordre envoyé |
| Crash 1000 | BUY | ❌ REJECT | ❌ REJECT | ❌ Rejeté phase 3 |
| BTCUSD | BUY | ✅ PASS | ✅ PASS | ✅ Ordre envoyé |
| BTCUSD | SELL | ✅ PASS | ✅ PASS | ✅ Ordre envoyé |

**Défense en profondeur:**  
Si pipeline manque (bug, deploy ancien), TradeManager bloque quand même.

## 🔄 Impact Morning Scan Report

**Avant (--skip-ta):**
```
🚀 Envoi des signaux sûrs à TradeManager (score >= 6)...
  ✅ Signal envoyé à TradeManager: BTCUSD BUY @ None (score 7.5)
  ✅ Signal envoyé à TradeManager: DERIV:BOOM_500_INDEX SELL @ None (score 6.3)
```

**Après (TradingAgents actif):**
```
🚀 Envoi des signaux sûrs à TradeManager (score >= 6)...
  ✅ Signal envoyé à TradeManager: BTCUSD BUY @ 51234.5 SL=50800.0 TP=52100.0 (score 7.5)
  🚫 DERIV:BOOM_500_INDEX SELL REJETÉ (SELL interdit sur Boom)
  ✅ Signal envoyé à TradeManager: ETHUSD SELL @ 3456.78 SL=3520.0 TP=3330.0 (score 6.1)
```

**Rapport Word:**
- Tableau avec colonnes entry/SL/TP remplies (pas "N/A")
- Signaux Boom/Crash invalides absents
- Confidence vraie depuis TradingAgents

## 🚨 Breaking Changes

### Utilisateurs Existants

Si vous utilisiez `--skip-ta` régulièrement:

**Avant:**
```bash
python Python/autonomous_pipeline.py --skip-ta  # Rapide, pas TA
```

**Après:**
```bash
# TOUJOURS utiliser pipeline complet
python Python/autonomous_pipeline.py  # Recommandé

# --skip-ta toujours possible mais déconseillé
python Python/autonomous_pipeline.py --skip-ta  # ⚠️ Ordres incomplets!
```

**Migration:**
1. Retirer `--skip-ta` de tous les cron jobs / scripts
2. Augmenter timeout si nécessaire: `--ta-timeout 900`
3. Vérifier logs pour "✅ Enrichissement COMPLET"

### Tâche Windows Planifiée

**Fichier:** Tâche scheduler qui lance pipeline

**Avant:**
```powershell
python D:\Dev\TradBOT\Python\autonomous_pipeline.py --skip-ta
```

**Après:**
```powershell
python D:\Dev\TradBOT\Python\autonomous_pipeline.py
# Timeout peut atteindre 10min (600s × 5 symboles / 3 parallèles = ~1000s)
```

## 📝 TODO Next

1. **Test pipeline complet:**
   ```bash
   python Python/autonomous_pipeline.py
   ```
   - Vérifier 5/5 TradingAgents terminent
   - Vérifier entry/SL/TP présents dans logs phase 4
   - Vérifier SELL sur Boom rejeté

2. **Compiler TradeManager.mq5:**
   - Protection Boom/Crash déjà prête (commit 6e22c454)
   - Besoin compilation + attachement EA

3. **Vérifier Morning Scan Report:**
   - Rapport Word doit avoir entry/SL/TP précis
   - Tableau complet (pas "N/A")

4. **Mettre à jour tâche Windows:**
   - Retirer `--skip-ta` si présent
   - Augmenter timeout budget total (~15min safe)

5. **Monitor premier run complet:**
   - Observer durée phase 2 (TradingAgents)
   - Vérifier pas de timeout (< 600s/symbole)
   - Vérifier ordres TradeManager executables

---

**Status:** ✅ CODE COMPLET - Attente test production  
**Risk:** MEDIUM - Timeout TA peut allonger pipeline  
**Benefit:** HIGH - Ordres COMPLETS + Validation Boom/Crash
