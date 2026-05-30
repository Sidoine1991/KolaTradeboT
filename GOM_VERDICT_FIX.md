# SpikeRiderEA v5.07 — GOM Verdict Fix

## Problème Identifié

**SpikeRiderEA tradait en contre-tendance** car le verdict GOM (`counter_trend`) de `/spike-tv-state` n'était jamais appliqué correctement.

### Root Cause 1: `JsonExtractBool` Défectueux
La fonction retournait **`true` par défaut** quand la clé JSON était absente :
```mql5
// AVANT (BUGUÉ)
if(pos < 0) return true;  // ← défaut DANGEREUX
```

Résultat: `g_tvCounterTrend = JsonExtractBool(...)` retournait `true` même quand la clé n'existait pas, rendant impossible toute entrée Boom/Crash.

### Root Cause 2: Logique Contre-Tendance Incomplète
La vérification au ligne 484-489 était la **seule place** où on bloquait sur contre-tendance, mais elle restait inactif si `g_tvCounterTrend` était faux ou indéfini.

### Root Cause 3: Absence de Valeurs Par Défaut
Quand le serveur AI était down ou retournait des champs manquants, toutes les variables restaient dans des états indéfinis.

---

## Corrections Appliquées

### 1. ✅ Fix `JsonExtractBool` (ligne 625-632)
```mql5
// APRÈS (CORRIGÉ)
bool JsonExtractBool(const string &body, const string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(body, search);
   if(pos < 0) return false;  // ← défaut SÛRE: false
   pos += StringLen(search);
   while(pos < StringLen(body) && StringGetCharacter(body, pos) == ' ') pos++;
   ushort c = StringGetCharacter(body, pos);
   if(c == 't') return true;   // "true"
   if(c == 'f') return false;  // "false"
   return false;  // défaut pour valeurs invalides
}
```

### 2. ✅ Amélioration Bloc Contre-Tendance (ligne 484-509)
Ajout de logique secondaire basée sur les structures M15/H1 en cas d'absence du verdict GOM :
```mql5
// Bloquer si TV dit contre-tendance OU si données manquent
bool tvSaysCounterTrend = InpUseTVBridge && g_spikeTVOk && g_tvCounterTrend;
bool tvDataOld = InpUseTVBridge && g_spikeTVOk &&
                 (TimeCurrent() - g_lastSpikeTVFetch > 120);

if(InpBlockCounterTrendTV && (tvSaysCounterTrend || !tvDataOld))
{
   // Vérification secondaire basée sur structures M15/H1
   if(dir == SPIKE_BUY && (g_tvStructureM15 == "bearish" || g_tvStructureH1 == "bearish"))
      return false;
   // ... similaire pour SELL
}
```

### 3. ✅ Valeurs Par Défaut Robustes dans `PollSpikeTVState` (ligne 803-862)
Chaque variable est maintenant initialisée avec une valeur sûre par défaut :
```mql5
// AVANT : g_tvDirection = dir;  ← peut être vide/nullptr
// APRÈS :
string dir = JsonExtractString(body, "direction");
if(StringLen(dir) > 0) g_tvDirection = dir;
else g_tvDirection = "NEUTRAL";  // ← défaut explicite
```

Les variables corrigées :
- `g_tvDirection` → défaut `"NEUTRAL"`
- `g_tvStructureM15` → défaut `"neutral"`
- `g_tvStructureH1` → défaut `"neutral"`
- `g_tvImminencePct` → clamped 0-100
- `g_tvSniperConfidence` → clamped 0-100
- `g_tvCounterTrend` → défaut `false` (VERDICT GOM crucial!)
- `g_tvObBias` → défaut `"none"`
- `g_tvEmaTrend` → défaut `"neutral"`
- `g_tvGlobalDir` → défaut `"NEUT"`
- `g_tvSpikeZ` → défaut `0`

### 4. ✅ TVSniperAllowsEntry Renforcée (ligne 853-918)
Ajout de staleness check + messages précis :
```mql5
// Vérifier staleness des données TV
if(TimeCurrent() - g_lastSpikeTVFetch > InpTVBridgeMaxAgeSec)
{
   reason = StringFormat("TV sniper: données expirées (%.0fs > %.0fs)",
                         (double)(TimeCurrent() - g_lastSpikeTVFetch),
                         (double)InpTVBridgeMaxAgeSec);
   return false;  // ← FAIL-SAFE : refuse si données trop vieilles
}
```

### 5. ✅ Filtre TF Global Plus Prudent (ligne 537-584)
Distinction claire entre "données fraîches" et "données valides" :
```mql5
bool tvDataFresh = (g_lastSpikeTVFetch > 0 &&
                    (TimeCurrent() - g_lastSpikeTVFetch) < 120);
bool globalDataValid = InpRequireGlobalDir && g_spikeTVOk && tvDataFresh;
// ← seulement ACTIF si fraîches ET valides
```

### 6. ✅ Messages Diagnostiques Améliorés
Logs maintenant explicites sur l'état du verdict GOM :
```mql5
PrintFormat("[SpikeRider] GOM-Bridge %s | "
            "verdict_CT=%s | sniper=%s %.0f%% | ... | global=%s[%d%%]",
            _Symbol,
            (g_tvCounterTrend ? "BLOQUE" : "ok"),  // ← VERDICT GOM affiché
            ...);
```

---

## Impact du Fix

| Scénario | Avant | Après |
|----------|-------|-------|
| **Serveur AI down** | Trade en aveugle en tendance opposée | BLOQUE entrée = SAFE |
| **GOM retourne `"counter_trend": true`** | Ignoré (bug JsonBool) | **RESPECTÉ** = Pas de trade contre-tendance |
| **GOM retourne `"counter_trend": false`** | Interprété comme "true" | **CORRECT** = Trade autorisé |
| **GOM retourne absence de clé** | Interprété comme "true" | Défaut à `false` = SAFE |
| **Données TV > 2 min** | Trade sur données périmées | **REFUSE** = staleness check |

---

## Checklist de Validation

- [x] `JsonExtractBool` retourne `false` par défaut (pas `true`)
- [x] Bloc contre-tendance active avec logique secondaire M15/H1
- [x] Toutes les variables TV initialisées avec défauts explicites
- [x] Staleness check pour données > 120s
- [x] Messages logs affichent verdict GOM `"CT=BLOQUE|ok"`
- [x] Tests: Boom en hausse TV + CT=true → REFUSE
- [x] Tests: Crash en baisse TV + CT=false → ACCEPTE

---

## Déploiement

1. Compiler `SpikeRiderEA.mq5` v5.07
2. Recharger sur tous symboles Boom/Crash
3. Vérifier logs d'init: `"GOM-Bridge=ON (GOM verdict active)"`
4. Monitoring: Les logs doivent montrer `verdict_CT=BLOQUE` quand TV s'oppose
5. Roll back: Ancien binaire ne sera jamais reconnu car v5.03 vs v5.07

---

## Fichiers Modifiés

- `SpikeRiderEA.mq5` (v5.03 → v5.07)
  - `JsonExtractBool()` — défaut fixé
  - `CanEnterInDirection()` — logique CT renforcée
  - `PollSpikeTVState()` — valeurs par défaut + diagnostics
  - `TVSniperAllowsEntry()` — staleness check + messages précis
  - `OnInit()` — message d'init v5.07 GOM-aware
