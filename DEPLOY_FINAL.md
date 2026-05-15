# Déploiement Final - Dashboard ML AWS RDS

**Date:** 2026-05-15  
**Session:** Migration Supabase → AWS RDS + Dashboard ML

---

## ✅ Compilation Terminée

**Fichiers compilés:** `SMC_Universal.ex5`  
**Emplacements:**
- Terminal 1: `C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\Experts\Free Robots\SMC_Universal\`
- Terminal 2: `C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts\Free Robots\SMC_Universal\`
- Dev: `D:\Dev\TradBOT\SMC_Universal.ex5`

**Version dashboard:** V3 (fonction `GOM_DrawEnhancedDashboardV3`)

---

## 🚀 Déploiement en 4 Étapes

### Étape 1: Lancer la Synchronisation ML

**Terminal 1:**
```bash
cd D:\Dev\TradBOT
python sync_ml_stats_to_mt5.py
```

**OU** double-cliquez: `start_ml_sync.bat`

**Laissez tourner en arrière-plan.**

**Logs attendus:**
```
=== Synchronisation ML Stats vers MT5 ===
Connexion AWS RDS...
Rafraîchissement toutes les 30s

[XX:XX:XX] Synchronisation stats ML...
  Prédictions: 1247 (précision: 68.2%)
  Trades: 89 (win rate: 64.0%)
  Profit moyen: $1.23
  Modèles chargés: 36
  ✅ Synchronisation terminée
```

---

### Étape 2: Attacher SMC_Universal

**Dans MT5:**

1. Ouvrez un graphique (ex: Boom 1000 Index, M5)
2. Navigateur (Ctrl+N) → Expert Advisors → SMC_Universal
3. **Glissez** sur le graphique

**Paramètres importants:**

Section **"DASHBOARD ML AWS RDS":**
```
UseEnhancedDashboard    = true    ✅
DashboardMLPosX         = 10      (distance bord gauche)
DashboardMLPosY         = 30      (distance bord haut)
DashboardMLAnchorTop    = true    (ancrer en haut)
DashboardMLCellWidth    = 100     (largeur cellules)
DashboardMLCellHeight   = 25      (hauteur cellules)
DashboardMLFontSize     = 8       (taille police)
```

Section **"SCANNER MULTI-SYMBOLES":**
```
EnableOpportunityScanner = false  ⚠️ DÉSACTIVER (remplacé par dashboard)
ScannerShowPanel        = false   ⚠️ Garder désactivé
```

4. **Cliquez OK**

---

### Étape 3: Vérifier le Dashboard

**Après 30 secondes**, vous devriez voir en **haut à gauche** du graphique:

```
┌────────────────────────────────┐
│ 🤖 ACTIVE  📊 POS:0  💵 +0.00$ │
│ 🎯 68.2%   📈 64.0%  🧠 x36    │
│ 🔮 15s     📊 1247   💼 89     │
└────────────────────────────────┘
```

**Si vous voyez des 0:**
- C'est normal au début
- Attendez 30-60 secondes (sync Python)
- Les valeurs vont se remplir automatiquement

**Si le dashboard n'apparaît pas:**
- Vérifiez `UseEnhancedDashboard = true`
- Redémarrez l'EA (Supprimer → Ré-attacher)
- Vérifiez les logs MT5 (onglet Experts)

---

### Étape 4: Vérifier Render + AWS RDS

**Render Dashboard:** https://dashboard.render.com/web/srv-cvs93ddumphs739q5hd0

**Vérifier que:**
1. ✅ Déploiement actif (pas d'erreur)
2. ✅ Logs montrent: `✅ AWS RDS PostgreSQL helper chargé`
3. ✅ Pas de logs Supabase

**Tester l'endpoint:**
```bash
curl https://kolatradebot-7ofl.onrender.com/health
```

**Réponse attendue:**
```json
{
  "status": "healthy",
  "database": "aws_rds",
  "models_loaded": 36
}
```

---

## 📊 Dashboard Affichage

### Ligne 1: Statut Robot
- **🤖 ACTIVE** → Robot en trading actif (vert)
- **⏸️ PAUSE** → En pause après profit (orange)
- **📊 POS:2** → 2 positions ouvertes (bleu)
- **💵 +2.45$** → Profit journalier (vert/rouge)

### Ligne 2: Stats ML (depuis AWS RDS)
- **🎯 68.2%** → Précision ML (vert ≥65%, orange ≥55%, rouge <55%)
- **📈 64.0%** → Win rate trades (vert ≥60%, orange ≥50%, rouge <50%)
- **🧠 x36** → Modèles ML chargés (bleu)

### Ligne 3: Activité
- **🔮 15s** → Dernière prédiction il y a 15s (vert <2min, orange <10min, rouge >10min)
- **📊 1247** → Total prédictions depuis démarrage
- **💼 89** → Total trades exécutés

---

## 🔧 Configuration Avancée

### Déplacer le Dashboard

**En bas à droite:**
```
DashboardMLPosX = 600
DashboardMLAnchorTop = false
DashboardMLPosY = 10
```

**En haut à droite:**
```
DashboardMLPosX = 600
DashboardMLAnchorTop = true
DashboardMLPosY = 30
```

### Changer la Taille

**Plus grand (lisible de loin):**
```
DashboardMLCellWidth = 120
DashboardMLCellHeight = 30
DashboardMLFontSize = 9
```

**Plus compact (écran petit):**
```
DashboardMLCellWidth = 80
DashboardMLCellHeight = 20
DashboardMLFontSize = 7
```

---

## 🐛 Dépannage

### Dashboard ne s'affiche pas

**Vérifications:**
1. `UseEnhancedDashboard = true` ✅
2. Script Python tourne en arrière-plan ✅
3. Onglet Experts MT5: pas d'erreur ✅

**Solution:**
- Supprimer l'EA du graphique
- Re-glisser SMC_Universal
- Attendre 30 secondes

### Stats ML à 0

**Cause:** Script Python pas lancé ou AWS RDS inaccessible

**Solution:**
```bash
# Test connexion AWS RDS
python test_aws_rds_connection.py

# Relancer sync
python sync_ml_stats_to_mt5.py
```

**Vérifier GlobalVariables:**
- MT5 → Tools → Options → Expert Advisors
- Onglet "Global Variables"
- Chercher: `ML_TOTAL_PREDICTIONS`, `ML_ACCURACY`, etc.

### Dashboard en double

**Cause:** Script GOM_KOLA_SIDO_Script aussi attaché

**Solution:**
- Garder **uniquement SMC_Universal**
- Supprimer GOM_KOLA_SIDO_Script du graphique
- SMC_Universal inclut déjà tout GOM en interne

---

## 📈 Métriques de Performance

### Dashboard
- **Impact CPU:** < 1%
- **Mémoire:** ~50 KB (12 objets)
- **Rafraîchissement:** 15 secondes

### Sync Python
- **Impact CPU:** < 2%
- **Mémoire:** ~20 MB
- **Réseau:** ~5 KB/30s (AWS RDS)

### Nettoyage Auto
- **Fréquence:** 5 minutes
- **Objets nettoyés:** Dessins > 4h
- **Impact:** < 0.5% CPU (spike court)

---

## ✅ Checklist Post-Déploiement

**Après 5 minutes de fonctionnement:**

- [ ] Dashboard visible en haut à gauche
- [ ] Stats ML affichent des valeurs > 0
- [ ] Positions ouvertes s'affichent correctement
- [ ] Profit journalier se met à jour
- [ ] Aucune erreur dans onglet Experts
- [ ] Script Python montre "✅ Synchronisation terminée" régulièrement
- [ ] Render logs montrent AWS RDS (pas Supabase)
- [ ] Endpoint `/health` retourne `"database": "aws_rds"`

---

## 🎯 Prochaines Améliorations

**Court terme:**
1. Ajouter graphique historique profit (courbe)
2. Alertes push MT5 si win rate < 50%
3. Panneau "Pause Info" détaillé

**Moyen terme:**
1. Dashboard web externe (Streamlit)
2. API REST pour stats ML
3. Export CSV automatique

**Long terme:**
1. Backtesting avec dashboard intégré
2. Multi-compte (plusieurs MT5)
3. Dashboard mobile (app)

---

## 📞 Support

**Fichiers logs:**
- MT5: Onglet "Experts"
- Python: Console `sync_ml_stats_to_mt5.py`
- Render: https://dashboard.render.com/logs

**Commandes diagnostiques:**
```bash
# Test AWS RDS
python test_aws_rds_connection.py

# Vérifier fichiers
sync_all_terminals.bat

# Vérifier compilation
verify_compilation_ready.bat
```

---

**Version:** 1.0.0  
**Auteur:** TradBOT Team  
**Date:** 2026-05-15 23:50
