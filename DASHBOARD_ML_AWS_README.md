# Tableau de Bord ML AWS - Guide Complet

## 📊 Vue d'ensemble

Le nouveau tableau de bord affiche en temps réel:
- **Statut du robot** (actif, pause, arrêt)
- **Positions ouvertes** et profit journalier
- **Stats ML depuis AWS RDS** (précision, win rate, modèles chargés)
- **Activité du système** (dernière prédiction, total trades)
- **Nettoyage automatique** des dessins expirés

---

## 🚀 Installation

### Étape 1: Compiler le script MQ5

1. Ouvrez **MetaEditor**
2. Ouvrez `GOM_KOLA_SIDO_Script.mq5`
3. Appuyez sur **F7** (Compiler)
4. Vérifiez: **0 erreur(s), 0 avertissement(s)**

### Étape 2: Lancer la synchronisation ML

Le script Python `sync_ml_stats_to_mt5.py` récupère les stats depuis AWS RDS et les envoie vers MT5.

```bash
# Depuis D:\Dev\TradBOT\
python sync_ml_stats_to_mt5.py
```

**Ce que fait le script:**
- ✅ Se connecte à AWS RDS PostgreSQL
- ✅ Récupère les tables: `predictions`, `trade_feedback`, `model_metrics`
- ✅ Calcule: précision ML, win rate, profit moyen
- ✅ Envoie vers MT5 via `GlobalVariableSet()`
- ✅ Rafraîchit toutes les **30 secondes**

**Logs attendus:**
```
=== Synchronisation ML Stats vers MT5 ===
Connexion AWS RDS...
Rafraîchissement toutes les 30s

[20:15:30] Synchronisation stats ML...
  Prédictions: 1247 (précision: 68.2%)
  Trades: 89 (win rate: 64.0%)
  Profit moyen: $1.23
  Modèles chargés: 36
  ✅ Synchronisation terminée
```

### Étape 3: Attacher le script au graphique MT5

1. Dans **MT5**, glissez `GOM_KOLA_SIDO_Script` sur un graphique
2. Dans les paramètres d'entrée:
   - ✅ `UseEnhancedDashboard = true` (nouveau tableau de bord)
   - ✅ `DeferToSMC_UniversalEA = false` (si pas d'EA actif)
   - ✅ `KeepScriptAttached = true` (garder attaché)
3. Cliquez **OK**

---

## 📋 Tableau de Bord - Contenu

### LIGNE 1: Statut Robot
| Cellule | Signification | Couleurs |
|---------|---------------|----------|
| 🤖 ACTIVE | Robot en mode trading actif | Vert |
| ⏸️ PAUSE | Robot en pause (après profit target) | Orange |
| ⏸️ STOPPED | Robot arrêté | Gris foncé |
| 📊 POS:2 | Nombre de positions ouvertes | Bleu |
| 💵 +2.45$ | Profit journalier | Vert si +, Rouge si - |

### LIGNE 2: Info Pause (affichée seulement si robot en pause)
| Cellule | Signification |
|---------|---------------|
| TARGET HIT | Raison de la pause (objectif atteint) |
| ⏱️ 2h30m | Temps restant avant reprise |

**Autres raisons de pause:**
- `MAX DD` → Drawdown maximal atteint
- `RISK LIMIT` → Limite de risque atteinte
- `MANUAL` → Pause manuelle

### LIGNE 3: Stats ML
| Cellule | Signification | Couleurs |
|---------|---------------|----------|
| 🎯 68.2% | Précision des prédictions ML | Vert si ≥65%, Orange si ≥55%, Rouge sinon |
| 📈 64.0% | Taux de réussite (win rate) trades | Vert si ≥60%, Orange si ≥50%, Rouge sinon |
| 🧠 x36 | Nombre de modèles ML chargés | Bleu |

### LIGNE 4: Activité ML
| Cellule | Signification | Couleurs |
|---------|---------------|----------|
| 🔮 15s | Dernière prédiction (temps écoulé) | Vert si <2min, Orange si <10min, Rouge sinon |
| 📊 1247 | Total prédictions depuis démarrage | Gris foncé |
| 💼 89 | Total trades exécutés | Gris foncé |

---

## 🔧 Configuration Avancée

### Modifier la position du tableau de bord

Dans `GOM_Enhanced_Dashboard.mqh` (ligne ~250):

```mql5
// Configuration layout
int baseX = 10;   // Distance depuis le bord gauche (pixels)
int baseY = 10;   // Distance depuis le bord bas (pixels)
int cellW = 90;   // Largeur cellule
int cellH = 24;   // Hauteur cellule
int gap = 2;      // Espace entre cellules
int fontSize = 7; // Taille police (7 = compact, 9 = lisible, 11 = grand)
```

### Changer les couleurs

```mql5
color bgDark = 0x1E1E1E;    // Gris très foncé (fond neutre)
color bgGreen = 0x2E7D32;   // Vert mat (succès)
color bgRed = 0xC62828;     // Rouge mat (perte/erreur)
color bgOrange = 0xEF6C00;  // Orange (pause/warning)
color bgBlue = 0x1565C0;    // Bleu mat (info)
```

**Format couleur:** `0xBBGGRR` (hex BGR, pas RGB!)

### Modifier la fréquence de rafraîchissement

Dans `GOM_KOLA_SIDO_Script.mq5` (paramètres d'entrée):

```mql5
input int DashboardRefreshSeconds = 15;  // 15s par défaut
```

---

## 🧹 Nettoyage Automatique

Le système nettoie automatiquement:

### Objets expirés
- ✅ Lignes de tendance GOM/KOLA/SIDO > 4h
- ✅ Objets avec `OBJPROP_TIME` expiré
- ✅ Dessins obsolètes (préfixes: GOM_, DASH_, KOLA_, SIDO_)

### Fréquence
Toutes les **5 minutes** (fonction `GOM_CleanExpiredDrawings()`)

**Désactiver le nettoyage (déconseillé):**
Commenter la ligne dans `GOM_Enhanced_Dashboard.mqh` (~252):
```mql5
// GOM_CleanExpiredDrawings(); // DÉSACTIVÉ
```

---

## 🔌 Intégration avec ai_server

Le serveur IA doit publier les stats dans MT5 GlobalVariables.

### Variables attendues

| Variable MT5 | Source AWS RDS | Description |
|--------------|----------------|-------------|
| `ML_TOTAL_PREDICTIONS` | `predictions` table | Nombre total de prédictions |
| `ML_ACCURATE_PREDICTIONS` | `predictions` (confidence > 0.7) | Prédictions correctes |
| `ML_TRADES_TOTAL` | `trade_feedback` table | Total trades exécutés |
| `ML_TRADES_WIN` | `trade_feedback` (profit_usd > 0) | Trades gagnants |
| `ML_AVG_PROFIT_USD` | AVG(profit_usd) | Profit moyen par trade |
| `ML_LAST_TRAINING` | `model_metrics.timestamp` | Timestamp dernier entraînement |
| `ML_LAST_PREDICTION` | `predictions.created_at` | Timestamp dernière prédiction |
| `ML_MODELS_LOADED` | `model_metrics.models_loaded` | Nombre de modèles chargés |

### Variables robot

| Variable MT5 | Description |
|--------------|-------------|
| `ROBOT_ACTIVE` | 1.0 = actif, 0.0 = inactif |
| `ROBOT_PAUSED` | 1.0 = en pause, 0.0 = normal |
| `ROBOT_PAUSE_UNTIL` | Timestamp de reprise (epoch) |
| `ROBOT_PAUSE_REASON` | 1=TARGET_HIT, 2=MAX_DD, 3=RISK_LIMIT |
| `ROBOT_DAILY_PROFIT` | Profit journalier en USD |
| `ROBOT_TARGET_PCT` | % de l'objectif journalier atteint |

---

## 🐛 Dépannage

### Problème: Dashboard n'apparaît pas

**Vérifications:**
1. ✅ Script attaché au graphique (coin supérieur droit MT5 → icône script)
2. ✅ `UseEnhancedDashboard = true` dans les paramètres
3. ✅ `ShowBottomDashboard = true` dans les paramètres
4. ✅ Logs MT5: "GOM_KOLA_SIDO_Script" sans erreur

**Solution:**
- Redémarrer le script (clic droit → Supprimer → ré-attacher)
- Compiler à nouveau (`F7` dans MetaEditor)

### Problème: Stats ML affichent 0

**Vérifications:**
1. ✅ `sync_ml_stats_to_mt5.py` est en cours d'exécution
2. ✅ Connexion AWS RDS valide (logs montrent "Synchronisation terminée")
3. ✅ GlobalVariables créées: Tools → Options → Expert Advisors → vérifier les GV

**Solution:**
```bash
# Tester la connexion AWS RDS
python test_aws_rds_connection.py

# Relancer le sync
python sync_ml_stats_to_mt5.py
```

### Problème: "UseEnhancedDashboard" non reconnu

**Cause:** Compilation avant sauvegarde du fichier.

**Solution:**
1. Vérifier que la ligne existe (ligne ~66):
   ```mql5
   input bool   UseEnhancedDashboard = true;
   ```
2. Sauvegarder (`Ctrl+S`)
3. Recompiler (`F7`)

### Problème: Dessins anciens ne se suppriment pas

**Vérifications:**
- ✅ Fonction `GOM_CleanExpiredDrawings()` appelée (voir logs)
- ✅ Objets ont bien les préfixes: `GOM_`, `DASH_`, `KOLA_`, `SIDO_`

**Solution manuelle:**
```mql5
// Dans MetaEditor, exécuter une fois:
int total = ObjectsTotal(0, 0, -1);
for(int i = total - 1; i >= 0; i--)
{
   string name = ObjectName(0, i, 0, -1);
   if(StringFind(name, "GOM_") == 0) ObjectDelete(0, name);
}
```

---

## 🎨 Personnalisation Avancée

### Ajouter une nouvelle cellule

Dans `GOM_Enhanced_Dashboard.mqh`, après la ligne ~380:

```mql5
// Nouvelle cellule: Spread actuel
double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
string spreadTxt = "📏 " + DoubleToString(spread, 0) + "pt";
GOM_DrawDashCell("DASH_SPREAD", baseX + 3 * (cellW + gap), baseY + row * (cellH + gap),
                 cellW, cellH, spreadTxt, bgBlue, txtWhite, fontSize);
```

### Changer l'ancrage (coin du graphique)

Dans `GOM_DrawDashCell()` (ligne ~133), remplacer:

```mql5
// Ancrage coin bas gauche (défaut)
ObjectSetInteger(0, objName + "_BG", OBJPROP_CORNER, CORNER_LEFT_LOWER);

// Autres options:
// CORNER_LEFT_UPPER   → Haut gauche
// CORNER_RIGHT_UPPER  → Haut droit
// CORNER_RIGHT_LOWER  → Bas droit
```

### Ajouter des emojis

**Emojis testés (Windows MT5):**
- ✅ Statut: 🤖 ⏸️ 🛑 ✅ ❌ ⚠️
- ✅ Actions: 📊 💵 🎯 📈 🔮 💼 🧠
- ✅ Temps: ⏱️ ⏰ 📅
- ❌ Éviter: Emojis couleur (💚💛💔) → non supportés

---

## 📊 Exemple Visuel

```
┌─────────────┬─────────────┬─────────────┐
│ 🤖 ACTIVE   │ 📊 POS:2    │ 💵 +2.45$  │  ← Statut robot
├─────────────┴─────────────┴─────────────┤
│ 🎯 68.2%    │ 📈 64.0%    │ 🧠 x36     │  ← Stats ML
├─────────────┼─────────────┼─────────────┤
│ 🔮 15s      │ 📊 1247     │ 💼 89      │  ← Activité
└─────────────┴─────────────┴─────────────┘
```

**Avec pause active:**
```
┌─────────────┬─────────────┬─────────────┐
│ ⏸️ PAUSE    │ 📊 POS:0    │ 💵 +5.12$  │
├─────────────┴─────────────┴─────────────┤
│ TARGET HIT  │    ⏱️ 2h30m              │  ← Info pause
├─────────────┼─────────────┼─────────────┤
│ 🎯 71.5%    │ 📈 68.2%    │ 🧠 x36     │
├─────────────┼─────────────┼─────────────┤
│ 🔮 8m       │ 📊 2145     │ 💼 156     │
└─────────────┴─────────────┴─────────────┘
```

---

## ✅ Checklist Déploiement

Avant de démarrer le trading avec le nouveau dashboard:

- [ ] `GOM_KOLA_SIDO_Script.mq5` compilé sans erreur
- [ ] `sync_ml_stats_to_mt5.py` en cours d'exécution
- [ ] Connexion AWS RDS validée (logs montrent "Synchronisation terminée")
- [ ] Script attaché au graphique MT5
- [ ] `UseEnhancedDashboard = true` dans les paramètres
- [ ] Dashboard visible en bas à gauche du graphique
- [ ] Stats ML affichent des valeurs > 0
- [ ] Nettoyage automatique fonctionne (pas d'accumulation d'objets)

---

## 📞 Support

**Logs à vérifier:**
- MT5: Onglet "Experts" → Chercher "GOM_KOLA_SIDO_Script"
- Python: Console du script `sync_ml_stats_to_mt5.py`
- AWS RDS: CloudWatch logs (optionnel)

**Fichiers clés:**
- `D:\Dev\TradBOT\GOM_KOLA_SIDO_Script.mq5` → Script principal
- `D:\Dev\TradBOT\Include\GOM_Enhanced_Dashboard.mqh` → Dashboard
- `D:\Dev\TradBOT\sync_ml_stats_to_mt5.py` → Sync AWS → MT5

---

**Version:** 1.0.0  
**Date:** 2026-05-15  
**Auteur:** TradBOT Team
