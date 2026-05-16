# Résumé: Tableau de Bord ML + Nettoyage Auto + AWS RDS Stats

**Date:** 2026-05-15  
**Temps:** ~2h  
**Objectif:** Améliorer GOM_KOLA_SIDO_Script avec dashboard ML compact + nettoyage automatique

---

## ✅ Modifications Apportées

### 1. Nouveau fichier: `Include/GOM_Enhanced_Dashboard.mqh`

**Fonctions créées:**

#### `GOM_CleanExpiredDrawings()`
- Nettoie automatiquement les dessins expirés (>4h)
- Supprime objets avec préfixes: GOM_, DASH_, KOLA_, SIDO_
- Exécuté toutes les 5 minutes

#### `GOM_GetMLStats()`
- Récupère stats ML depuis MT5 GlobalVariables
- Données: predictions, trades, win rate, accuracy, modèles chargés

#### `GOM_GetRobotStatus()`
- État robot: actif, pause, arrêté
- Raison pause: TARGET_HIT, MAX_DD, RISK_LIMIT, MANUAL
- Temps restant avant reprise
- Positions ouvertes + profit journalier

#### `GOM_DrawDashCell()`
- Dessine une cellule de tableau moderne
- Background rectangle + texte centré
- Couleurs Material Design

#### `GOM_DrawEnhancedDashboard()`
- Dashboard compact 3-4 lignes
- Police taille 7 (très lisible, peu encombrant)
- Mise à jour automatique
- Position: bas gauche graphique

#### `GOM_CleanEnhancedDashboard()`
- Supprime tous les objets du dashboard
- Appelé dans OnDeinit

**Total lignes:** 417

---

### 2. Modifications: `GOM_KOLA_SIDO_Script.mq5`

#### Ajout include (ligne 5)
```mql5
#include <GOM_Enhanced_Dashboard.mqh>
```

#### Nouveau paramètre (ligne 66)
```mql5
input bool UseEnhancedDashboard = true; // Tableau de bord ML AWS RDS
```

#### Paramètre corrigé (ligne 141)
```mql5
input bool DeferToSMC_UniversalEA = false; // Script tourne indépendamment
```

#### OnDeinit ajouté (ligne ~5803)
```mql5
void OnDeinit(const int reason)
{
   if(UseEnhancedDashboard)
      GOM_CleanEnhancedDashboard();
   Print("GOM_KOLA_SIDO_Script: OnDeinit appelé");
}
```

#### Appel dashboard modifié (2 endroits)
```mql5
// Une seule exécution (ligne ~5829)
if(UseEnhancedDashboard)
   GOM_DrawEnhancedDashboard();
else
   DrawBottomDashboard();

// Boucle infinie (ligne ~5889)
if(UseEnhancedDashboard)
   GOM_DrawEnhancedDashboard();
else
   DrawBottomDashboard();
```

---

### 3. Nouveau fichier: `sync_ml_stats_to_mt5.py`

**Rôle:** Synchroniser stats AWS RDS → MT5 GlobalVariables

**Fonctions:**

#### `set_global_variable(name, value)`
- Envoie une variable vers MT5
- Mode simulation si MT5 pas installé

#### `get_ml_stats_from_rds()`
- Se connecte à AWS RDS via `aws_rds_helper`
- Récupère tables:
  - `predictions` → total, accuracy, last prediction
  - `trade_feedback` → total trades, win rate, profit moyen
  - `model_metrics` → last training, models loaded

#### `sync_ml_stats()`
- Calcule métriques (accuracy %, win rate %)
- Envoie 8 variables vers MT5:
  - `ML_TOTAL_PREDICTIONS`
  - `ML_ACCURATE_PREDICTIONS`
  - `ML_TRADES_TOTAL`
  - `ML_TRADES_WIN`
  - `ML_AVG_PROFIT_USD`
  - `ML_LAST_TRAINING`
  - `ML_LAST_PREDICTION`
  - `ML_MODELS_LOADED`
- Envoie 6 variables robot:
  - `ROBOT_ACTIVE`
  - `ROBOT_PAUSED`
  - `ROBOT_PAUSE_UNTIL`
  - `ROBOT_PAUSE_REASON`
  - `ROBOT_DAILY_PROFIT`
  - `ROBOT_TARGET_PCT`

#### `main()`
- Boucle infinie avec rafraîchissement toutes les 30s
- Gestion Ctrl+C

**Total lignes:** 226

---

### 4. Nouveau fichier: `start_ml_sync.bat`

- Lance `sync_ml_stats_to_mt5.py`
- Active venv si présent
- Interface console colorée
- Pause à la fin

---

### 5. Documentation: `DASHBOARD_ML_AWS_README.md`

**Sections:**

1. Vue d'ensemble (features)
2. Installation (3 étapes)
3. Contenu du tableau de bord (4 lignes détaillées)
4. Configuration avancée (position, couleurs, refresh)
5. Nettoyage automatique (fréquence, objets)
6. Intégration ai_server (variables attendues)
7. Dépannage (5 problèmes courants + solutions)
8. Personnalisation (ajouter cellules, ancrage, emojis)
9. Exemple visuel (ASCII art)
10. Checklist déploiement

**Total lignes:** 449

---

## 📊 Structure du Dashboard

### Sans pause
```
┌─────────────┬─────────────┬─────────────┐
│ 🤖 ACTIVE   │ 📊 POS:2    │ 💵 +2.45$  │  ← Ligne 1: Statut
├─────────────┼─────────────┼─────────────┤
│ 🎯 68.2%    │ 📈 64.0%    │ 🧠 x36     │  ← Ligne 2: Stats ML
├─────────────┼─────────────┼─────────────┤
│ 🔮 15s      │ 📊 1247     │ 💼 89      │  ← Ligne 3: Activité
└─────────────┴─────────────┴─────────────┘
```

### Avec pause
```
┌─────────────┬─────────────┬─────────────┐
│ ⏸️ PAUSE    │ 📊 POS:0    │ 💵 +5.12$  │  ← Ligne 1
├─────────────┴─────────────┴─────────────┤
│ TARGET HIT  │    ⏱️ 2h30m              │  ← Ligne 2: Pause info
├─────────────┼─────────────┼─────────────┤
│ 🎯 71.5%    │ 📈 68.2%    │ 🧠 x36     │  ← Ligne 3
├─────────────┼─────────────┼─────────────┤
│ 🔮 8m       │ 📊 2145     │ 💼 156     │  ← Ligne 4
└─────────────┴─────────────┴─────────────┘
```

**Caractéristiques:**
- ✅ Police taille 7 (compact, lisible)
- ✅ Couleurs Material Design (flat, moderne)
- ✅ Emojis pour reconnaissance rapide
- ✅ Cellules 90x24px (petit, non encombrant)
- ✅ Gap 2px (grille serrée)
- ✅ Position: bas gauche (10, 10)

---

## 🔄 Flux de Données

```
AWS RDS PostgreSQL
    ↓
sync_ml_stats_to_mt5.py (30s refresh)
    ↓
MT5 GlobalVariables (14 variables)
    ↓
GOM_Enhanced_Dashboard.mqh (lit les GV)
    ↓
GOM_DrawEnhancedDashboard() (affiche)
    ↓
MT5 Chart (dashboard visible)
```

---

## 🧹 Nettoyage Automatique

### Objets nettoyés
- Lignes de tendance > 4h
- Objets expirés (OBJPROP_TIME < now)
- Préfixes: GOM_, DASH_, KOLA_, SIDO_

### Fréquence
- Toutes les 5 minutes
- Fonction: `GOM_CleanExpiredDrawings()`

### Impact
- ✅ Prévient l'accumulation d'objets
- ✅ Maintient les performances
- ✅ Garde les niveaux récents seulement

---

## 🛠️ Installation Rapide

### 1. Compiler MQ5
```
MetaEditor → Ouvrir GOM_KOLA_SIDO_Script.mq5 → F7
```

### 2. Lancer sync AWS
```bash
cd D:\Dev\TradBOT\
python sync_ml_stats_to_mt5.py
```
**OU** double-cliquer: `start_ml_sync.bat`

### 3. Attacher script MT5
```
MT5 → Glisser script sur graphique → UseEnhancedDashboard=true → OK
```

---

## 📈 Métriques Affichées

| Métrique | Source | Calcul |
|----------|--------|--------|
| Précision ML | `predictions` table | (accurate / total) × 100% |
| Win Rate | `trade_feedback` table | (trades_win / total) × 100% |
| Profit Moyen | `trade_feedback` table | AVG(profit_usd) |
| Dernière Prédiction | `predictions.created_at` | now - last_timestamp |
| Modèles Chargés | `model_metrics.models_loaded` | COUNT(models) |
| Positions Ouvertes | MT5 PositionsTotal() | Comptage direct |
| Profit Journalier | GlobalVariable | Calculé par ai_server |

---

## 🎯 Avantages

### Ancien système
- ❌ Dashboard surchargé (18+ cellules)
- ❌ Police trop grande (encombrant)
- ❌ Pas de stats ML en temps réel
- ❌ Objets s'accumulent (lag)
- ❌ Pas d'info pause robot

### Nouveau système
- ✅ Dashboard compact (3-4 lignes)
- ✅ Police taille 7 (lisible, minimal)
- ✅ Stats ML AWS RDS live (30s refresh)
- ✅ Nettoyage auto toutes les 5min
- ✅ Info pause détaillée (raison + countdown)
- ✅ Emojis pour reconnaissance rapide
- ✅ Couleurs Material Design (professionnel)

---

## 🔐 Sécurité

### Connexion AWS RDS
- ✅ Credentials depuis .env
- ✅ SSL/TLS obligatoire (sslmode=require)
- ✅ Pas de credentials hardcodés

### MT5 GlobalVariables
- ✅ Lecture seule depuis MQ5
- ✅ Écriture uniquement par script Python autorisé
- ✅ Pas d'exposition externe

---

## 📂 Fichiers Créés

1. `Include/GOM_Enhanced_Dashboard.mqh` (417 lignes)
2. `sync_ml_stats_to_mt5.py` (226 lignes)
3. `start_ml_sync.bat` (22 lignes)
4. `DASHBOARD_ML_AWS_README.md` (449 lignes)
5. `RESUME_DASHBOARD_ML_2026-05-15.md` (ce fichier)

**Total:** 1114+ lignes de code + documentation

---

## ✅ Tests Requis

### Test 1: Compilation
- [ ] GOM_KOLA_SIDO_Script.mq5 compile sans erreur
- [ ] Include GOM_Enhanced_Dashboard.mqh trouvé

### Test 2: Sync Python
- [ ] `python sync_ml_stats_to_mt5.py` démarre
- [ ] Connexion AWS RDS réussie
- [ ] GlobalVariables créées dans MT5

### Test 3: Dashboard MT5
- [ ] Script attaché au graphique
- [ ] Dashboard visible bas gauche
- [ ] 3-4 lignes affichées
- [ ] Stats ML > 0

### Test 4: Nettoyage
- [ ] Attendre 10 minutes
- [ ] Vérifier: objets anciens supprimés
- [ ] Onglet Objects: pas d'accumulation

### Test 5: Pause Robot
- [ ] Simuler pause: `GlobalVariableSet("ROBOT_PAUSED", 1.0)`
- [ ] Ligne 2 apparaît (raison + countdown)
- [ ] Retirer pause: ligne 2 disparaît

---

## 🚀 Prochaines Étapes

### Court terme (cette session)
1. Compiler et tester localement
2. Vérifier déploiement Render (logs AWS RDS)
3. Valider endpoints /decision et /trades/feedback

### Moyen terme
1. Intégrer stats pause dans SMC_Universal
2. Ajouter graphique historique profit (courbe)
3. Alertes push MT5 si win rate < 50%

### Long terme
1. Dashboard web externe (Streamlit)
2. API REST pour récupérer stats ML
3. Backtesting automatique avec métriques dashboard

---

## 📝 Notes Importantes

### Script se détachait automatiquement
**Cause:** `DeferToSMC_UniversalEA = true` (ligne 141)  
**Fix:** Changé en `false` pour permettre script indépendant  
**Alternative:** Laisser `true` si SMC_Universal actif sur le même graphique

### Dashboard encombré
**Cause:** Ancien système avec 18 cellules + fonte taille 9-11  
**Fix:** Nouveau système 3-4 lignes, fonte 7, cellules 90x24px

### Stats ML à 0
**Cause:** `sync_ml_stats_to_mt5.py` pas lancé  
**Fix:** Lancer le script Python en arrière-plan

### Objets s'accumulent
**Cause:** Pas de nettoyage automatique  
**Fix:** `GOM_CleanExpiredDrawings()` toutes les 5min

---

## 🎉 Résultat Final

Un tableau de bord **compact, informatif, et connecté à AWS RDS** qui affiche:
- ✅ État robot en temps réel
- ✅ Stats ML production (précision, win rate)
- ✅ Activité système (dernière prédiction, trades)
- ✅ Info pause détaillée (si applicable)
- ✅ Nettoyage automatique des dessins

**Taille finale:** ~1100 lignes de code  
**Temps d'implémentation:** ~2h  
**Impact performance:** Minimal (refresh 30s, nettoyage 5min)

---

**Auteur:** TradBOT Development Team  
**Date:** 2026-05-15 21:50  
**Version:** 1.0.0
