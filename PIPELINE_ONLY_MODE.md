# Mode Pipeline Only - TradeManager Exécuteur Passif

**Version:** TradeManager v3.19  
**Date:** 2026-06-07  
**Commit:** 708bd5d7

## 🎯 Objectif

Transformer TradeManager en **exécuteur passif** qui ne prend QUE les ordres du pipeline autonome, sans aucune initiative automatique.

## ⚙️ Activation

### Input MT5

```mql5
input bool PipelineOnlyMode = true;  // 🔒 MODE STRICT (défaut: ON)
```

**Défaut:** `true` (mode strict activé)  
**Pour désactiver:** Mettre à `false` dans les inputs MT5

### Vérification OnInit

Au démarrage, TradeManager affiche:

```
[TradeManager v3.19] Actif | 🔒 PipelineOnly=true | ...

┌─────────────────────────────────────────────────────────────┐
│  🔒 MODE PIPELINE ONLY ACTIF                               │
│  TOUTES les entrées automatiques sont DÉSACTIVÉES          │
│  TradeManager = EXÉCUTEUR PASSIF uniquement                │
│                                                             │
│  Ordres acceptés UNIQUEMENT depuis:                        │
│  → Pipeline autonome (autonomous_pipeline.py)              │
│  → /pending-order API (signaux MCP validés)                │
│                                                             │
│  BLOQUÉ:                                                    │
│  ❌ GOM AutoEntry / ReEntry                                │
│  ❌ TradingView Setups automatiques                        │
│  ❌ Re-entrées EMA                                         │
│  ❌ Duplications manuelles                                 │
│  ❌ Moteur Deriv (Boom/Crash spikes)                       │
└─────────────────────────────────────────────────────────────┘
```

## 🔒 Fonction de Garde

### `CanAutoEntry(context, symbol)`

Vérification systématique avant TOUTE entrée automatique:

```mql5
bool CanAutoEntry(const string context, const string sym = "")
{
   if(!PipelineOnlyMode)
      return true;  // Mode normal — toutes entrées auto autorisées

   // Mode strict — UNIQUEMENT ordres pipeline
   string symCheck = (StringLen(sym) > 0) ? sym : _Symbol;

   // 1. Vérifier whitelist pipeline
   if(!IsSymbolWhitelisted(symCheck))
   {
      PrintOnce(StringFormat("[%s] 🔒 BLOQUÉ: %s pas dans whitelist pipeline",
                context, symCheck), 120);
      return false;
   }

   // 2. Bloquer toutes entrées auto même si whitelist OK
   PrintOnce(StringFormat("[%s] 🔒 BLOQUÉ: Entrée auto désactivée (PipelineOnlyMode=true)",
             context), 120);
   return false;
}
```

**Logique:**
1. Si `PipelineOnlyMode=false` → Autoriser (mode normal)
2. Si symbole PAS dans whitelist pipeline → **BLOQUER**
3. Si symbole dans whitelist MAIS entrée auto → **BLOQUER quand même**
4. Seul `/pending-order` API peut exécuter (bypass la garde)

## 🚫 Fonctions Protégées (9 Points d'Entrée)

| Fonction | Description | Garde |
|----------|-------------|-------|
| `CheckGOMAutoEntry()` | Entrée auto GOM (GOOD/PERFECT verdict) | ✅ Ligne 4768 |
| `CheckGOMReEntry()` | Re-entrée GOM après correction | ✅ Ligne 4953 |
| `TryReEntryOnEMA()` | Re-entrée sur EMA fast/slow | ✅ Ligne 2539 |
| `TryTVSetupMarketBreakout()` | Breakout marché depuis setup TV | ✅ Ligne 1631 |
| `PlaceTVSetupLimitOrder()` | Ordre limit depuis setup TV | ✅ Ligne 1392 |
| `TryTVPreSpikeMarketEntry()` | Entrée pré-spike Boom/Crash | ✅ Ligne 1519 |
| `MonitorManualDuplicates()` | Duplication positions manuelles | ✅ Ligne 4136 |
| `DRV_UpdateCycle()` | Moteur Deriv (spikes Boom/Crash) | ✅ Ligne 3021 |
| Toutes entrées auto | Toute tentative d'entrée automatique | ✅ Garde systématique |

**Code pattern:**
```mql5
void CheckGOMAutoEntry()
{
   if(!UseGOMScalp || !UseGOMAutoEntry) return;

   // 🔒 GARDE PIPELINE ONLY MODE
   if(!CanAutoEntry("GOM-AutoEntry", _Symbol)) return;

   // ... reste du code
}
```

## ✅ Ordres Autorisés (Bypass Garde)

### 1. `/pending-order` API (Signaux MCP)

**Fonction:** `IngestPendingOrderForSymbol()`  
**Source:** Pipeline autonome via AI server  
**Ligne:** ~3420

**Workflow:**
```
Pipeline → POST /pending-order → AI Server → TradeManager poll
→ IngestPendingOrderForSymbol() → TryExecuteMCPSignal()
→ Exécution (BYPASS garde)
```

**Pas de garde** car:
- Signal validé par pipeline (TV+TA fusion)
- entry/SL/TP précis
- Direction validée (Boom/Crash rules)
- Whitelist pipeline respectée

### 2. Ordres Manuels Utilisateur

Les ordres passés **manuellement** dans MT5 (magic=0) sont exécutés normalement.  
**Duplication** de ces ordres est bloquée si `PipelineOnlyMode=true`.

## 📊 Workflow Complet

### Mode Pipeline Only (Recommandé)

```
┌────────────────────────────────────────────────────────────┐
│ 1. PIPELINE AUTONOME (autonomous_pipeline.py)             │
│    - Phase 1: Scan TradingView → Top-5                    │
│    - Phase 2: TradingAgents analyses → Entry/SL/TP        │
│    - Phase 3: Fusion TV+TA + Validation Boom/Crash        │
│    - Phase 4: POST /pending-order → AI Server             │
│    - Phase 5: Publish whitelist → pipeline_whitelist.json │
└────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────┐
│ 2. TRADEMANAGER (TradeManager.mq5)                        │
│    - Poll /pending-order (3s interval)                     │
│    - IngestPendingOrderForSymbol()                         │
│      → Validation Boom/Crash (ligne 3456)                  │
│      → Validation GOM (si UseGOMScalp)                     │
│      → TryExecuteMCPSignal()                               │
│    - Exécution ordre COMPLET (entry/SL/TP)                │
│    - 🔒 TOUTES entrées auto BLOQUÉES                      │
└────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────┐
│ 3. GESTION POSITION (Trailing/Stagnation/etc)             │
│    - Trailing stop (UseTrailing)                           │
│    - Profit stagnation exit (UseStagnationExit)           │
│    - Profit giveback protection                            │
│    - Global profit target                                  │
│    - Daily capital manager                                 │
└────────────────────────────────────────────────────────────┘
```

### Mode Auto Trading (PipelineOnlyMode=false)

```
┌────────────────────────────────────────────────────────────┐
│ TRADEMANAGER — Mode Auto Trading                          │
│ ✅ GOM AutoEntry (verdict GOOD/PERFECT)                   │
│ ✅ GOM ReEntry (après correction)                         │
│ ✅ TradingView Setups (TV MCP)                            │
│ ✅ Re-entrées EMA (fast/slow touch)                       │
│ ✅ Duplications manuelles (profit >= $2)                  │
│ ✅ Moteur Deriv (spikes Boom/Crash)                       │
│ ✅ Ordres pipeline (/pending-order)                       │
└────────────────────────────────────────────────────────────┘
```

**⚠️ Risques mode auto:**
- Trades non contrôlés par pipeline
- Signaux TV peuvent être invalides (SELL sur Boom)
- GOM auto-entry peut conflicter avec pipeline
- Duplications peuvent violer limites

## 📋 Whitelist Pipeline

### Fichier: `pipeline_whitelist.json`

**Chemin:** `C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\Common\Files\pipeline_whitelist.json`

**Format:**
```json
{
  "generated_at": "2026-06-07T14:30:00Z",
  "symbols": [
    {
      "symbol": "BTCUSD",
      "direction": "BUY",
      "score": 7.5
    },
    {
      "symbol": "ETHUSD",
      "direction": "SELL",
      "score": 6.1
    }
  ]
}
```

**Génération:**
- **Source:** `Python/autonomous_pipeline.py` phase 1
- **Fonction:** `_publish_pipeline_whitelist()`
- **Timing:** Après scan TradingView, avant TradingAgents
- **Durée validité:** Jusqu'au prochain pipeline run

**Utilisation TradeManager:**
```mql5
void LoadPipelineWhitelist()
{
   // Charger depuis Common/Files
   int fh = FileOpen("pipeline_whitelist.json", FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
   // Parser JSON simplement (sans lib externe)
   // Extraire "symbol": "XXX"
   // Stocker dans g_whitelistSymbols[]
}

bool IsSymbolWhitelisted(const string sym)
{
   LoadPipelineWhitelist();
   if(g_whitelistCount == 0)
      return (sym == _Symbol);  // Whitelist vide = chart courant uniquement

   for(int i = 0; i < g_whitelistCount; i++)
      if(g_whitelistSymbols[i] == sym) return true;

   return false;
}
```

## 🧪 Tests

### Test 1: Mode Pipeline Only (Défaut)

**Setup:**
1. Compiler TradeManager.mq5 v3.19
2. Attacher sur chart Boom 500 Index M1
3. Vérifier logs OnInit (bannière mode strict)

**Test GOM AutoEntry bloqué:**
```
1. Ouvrir TradingView → GOM verdict = PERFECT BUY
2. Attendre 5s (CheckIntervalSec)
3. ✅ Attendu: Log "[GOM-AutoEntry] 🔒 BLOQUÉ: Entrée auto désactivée"
4. ❌ Pas de trade ouvert
```

**Test Pipeline autorisé:**
```bash
python Python/autonomous_pipeline.py
# Observe Phase 4: Envoi ordres
# ✅ Attendu: TradeManager exécute ordres pipeline
# ✅ Log: "[TradeManager] ✅ MCP AUTO BUY BTCUSD @ ..."
```

### Test 2: Mode Auto (PipelineOnlyMode=false)

**Setup:**
1. Input MT5: `PipelineOnlyMode = false`
2. Recompiler + attacher EA
3. Vérifier log: "⚠️ MODE AUTO TRADING ACTIF"

**Test GOM AutoEntry autorisé:**
```
1. GOM verdict = PERFECT BUY
2. ✅ Attendu: Trade ouvert automatiquement
3. ✅ Log: "[GOM-Auto] ENTREE BUY Boom 500 Index ..."
```

### Test 3: Whitelist Vide

**Setup:**
```bash
# Supprimer whitelist
rm "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\Common\Files\pipeline_whitelist.json"
```

**Résultat:**
```
[Whitelist] Fichier introuvable: pipeline_whitelist.json
[GOM-AutoEntry] 🔒 BLOQUÉ: Boom 500 Index pas dans whitelist pipeline
```

**Comportement:**
- Whitelist vide = BLOQUER tout sauf symbole du chart courant
- Même le chart courant bloqué si entrée auto

## 🔄 Migration

### Utilisateurs Existants

**Avant (v3.18 et antérieur):**
- TradeManager prend des trades automatiques (GOM, TV, EMA, Deriv)
- Ordres en désordre pas contrôlés
- Pipeline + Auto Trading mixés

**Après (v3.19 avec PipelineOnlyMode=true):**
- TradeManager = exécuteur passif uniquement
- TOUS trades viennent du pipeline
- Contrôle total

**Migration Steps:**

1. **Compiler TradeManager.mq5 v3.19:**
   ```
   MetaEditor → File → Open → D:\Dev\TradBOT\TradeManager.mq5
   Compile (F7) → 0 errors
   ```

2. **Détacher anciens EA:**
   ```
   MT5 → Charts avec TradeManager → Clic droit → Expert Advisors → Remove
   ```

3. **Attacher nouveau EA:**
   ```
   Navigator → Expert Advisors → TradeManager v3.19
   Drag & drop sur Boom 500 Index M1
   Inputs: PipelineOnlyMode = true (défaut)
   OK
   ```

4. **Vérifier logs:**
   ```
   Toolbox → Expert → Chercher:
   "[TradeManager v3.19] Actif | 🔒 PipelineOnly=true"
   "MODE PIPELINE ONLY ACTIF"
   ```

5. **Tester pipeline:**
   ```bash
   python Python/autonomous_pipeline.py
   # Vérifier exécution ordres phase 4
   ```

### Backward Compatibility

**Switch simple:**
```mql5
// Mode strict (défaut recommandé)
input bool PipelineOnlyMode = true;

// Mode auto (ancien comportement)
input bool PipelineOnlyMode = false;
```

**Pas de breaking change:**
- Mode auto toujours disponible
- Utilisateurs peuvent choisir
- Recommandation: mode strict

## 📊 Logs Typiques

### Mode Pipeline Only

```
2026-06-07 15:00:00  [TradeManager v3.19] Actif | 🔒 PipelineOnly=true | ...
2026-06-07 15:00:00  ┌─────────────────────────────────────────────────┐
2026-06-07 15:00:00  │  🔒 MODE PIPELINE ONLY ACTIF                   │
2026-06-07 15:00:00  │  TOUTES les entrées automatiques DÉSACTIVÉES   │
2026-06-07 15:00:00  └─────────────────────────────────────────────────┘

2026-06-07 15:01:30  [GOM-AutoEntry] 🔒 BLOQUÉ: Entrée auto désactivée (PipelineOnlyMode=true)
2026-06-07 15:02:15  [TV-Breakout] 🔒 BLOQUÉ: Boom 500 Index pas dans whitelist pipeline
2026-06-07 15:03:45  [EMA-ReEntry] 🔒 BLOQUÉ: Attendre signal pipeline

2026-06-07 15:05:00  [TradeManager] 📡 Pending ready: BUY BTCUSD entry=51234.5 SL=50800.0 TP=52100.0 lot=0.01 market=OUI
2026-06-07 15:05:00  [TradeManager] ✅ MCP AUTO BUY BTCUSD @ 51234.5 SL=50800.0 TP=52100.0 lot=0.01 ticket=123456 dup=NON
```

### Mode Auto Trading

```
2026-06-07 15:00:00  [TradeManager v3.19] Actif | 🔒 PipelineOnly=false | ...
2026-06-07 15:00:00  ⚠️ MODE AUTO TRADING ACTIF — Toutes entrées auto autorisées

2026-06-07 15:01:30  [GOM-Auto] ENTREE BUY Boom 500 Index | PERFECT vnum=3 Q=85% C=78% lot=0.20
2026-06-07 15:02:15  [TV-Setup] ✅ BUY_LIMIT Boom 500 Index @ 15234.5 SL=15200.0 TP1=15300.0 (OB_BULLISH / valid)
2026-06-07 15:03:45  [TradeManager] ✅ Boom 500 Index re-entrée EMA8 #1 @ 15250.5
```

## ⚠️ Points d'Attention

### 1. Whitelist Stale

**Problème:** Whitelist non mise à jour depuis >1h  
**Solution:** Pipeline auto met à jour à chaque run (Phase 1)  
**Fallback:** Si whitelist vide → chart courant autorisé

### 2. Ordres Manuels

**Comportement:**
- Ordres manuels (magic=0) **exécutés normalement**
- **Duplication** bloquée si PipelineOnlyMode=true
- Gestion position (trailing, stagnation) **active**

### 3. Positions Existantes

**Avant migration v3.19:**
- Positions ouvertes par v3.18 continuent d'être gérées
- Trailing, stagnation, profit target **actifs**
- Re-entrée EMA **bloquée** si PipelineOnlyMode=true

### 4. Pipeline Fail

**Si pipeline échoue:**
- Whitelist stale → chart courant uniquement
- Ordres MCP (/pending-order) continuent de fonctionner
- Pas de nouveaux trades auto (mode strict)

**Recovery:**
```bash
# Relancer pipeline manuellement
python Python/autonomous_pipeline.py
# Vérifier whitelist générée
cat "C:/Users/USER/AppData/Roaming/MetaQuotes/Terminal/Common/Files/pipeline_whitelist.json"
```

## 🎓 Best Practices

### 1. Toujours Utiliser Mode Strict

```mql5
input bool PipelineOnlyMode = true;  // ✅ Recommandé
```

**Raisons:**
- Contrôle total sur trades exécutés
- Pas de surprise (GOM auto, TV setup)
- Pipeline = seule source de vérité
- Traçabilité complète (logs pipeline)

### 2. Vérifier Whitelist Avant Trading

```bash
# Morning routine
python Python/autonomous_pipeline.py
# Vérifier top-5 généré
cat "C:/Users/USER/AppData/Roaming/MetaQuotes/Terminal/Common/Files/pipeline_whitelist.json"
```

### 3. Monitor Logs Bloqués

**Chercher dans Expert Journal:**
```
🔒 BLOQUÉ: Entrée auto désactivée
🔒 BLOQUÉ: pas dans whitelist pipeline
```

**Si trop de blocages:**
- Vérifier pipeline exécuté récemment
- Vérifier whitelist publiée
- Vérifier symboles charts = symboles whitelist

### 4. Test Mode Auto Avant Production

```mql5
// Test environnement dev
input bool PipelineOnlyMode = false;

// Production toujours strict
input bool PipelineOnlyMode = true;
```

## 📈 Métriques

| Métrique | Avant (v3.18) | Après (v3.19 strict) |
|----------|---------------|----------------------|
| Sources entrées | 8+ (GOM, TV, EMA, etc.) | 1 (Pipeline uniquement) |
| Contrôle trades | Partiel | Total |
| Trades non désirés | Fréquents | 0 |
| Traçabilité | Difficile | Complète |
| Debug | Complex | Simple |

## 🔗 Références

- **Pipeline:** `Python/autonomous_pipeline.py`
- **TradeManager:** `TradeManager.mq5` v3.19
- **Commit:** 708bd5d7
- **Doc Pipeline:** `PIPELINE_WORKFLOW_FIX.md`
- **Doc Protection Boom/Crash:** `TRADEMANAGER_LOT_FIX.md`

---

**Résumé:** Mode Pipeline Only transforme TradeManager en exécuteur passif strict. Activé par défaut. Recommandé production. Switch simple pour mode auto.
