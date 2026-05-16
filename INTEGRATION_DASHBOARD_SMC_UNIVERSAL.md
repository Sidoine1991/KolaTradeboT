# Intégration Dashboard ML dans SMC_Universal

**Date:** 2026-05-15  
**Objectif:** Porter le tableau de bord ML AWS RDS dans SMC_Universal (EA principal)

---

## ✅ Avantages

### Avant
- ❌ Script `GOM_KOLA_SIDO_Script` séparé à attacher
- ❌ Script se détache si `DeferToSMC_UniversalEA=true`
- ❌ Dashboard en double (script + EA)
- ❌ Gestion de 2 programmes (script + EA)

### Maintenant
- ✅ **Dashboard intégré dans SMC_Universal**
- ✅ Un seul EA à gérer
- ✅ Dashboard toujours visible
- ✅ Pas de conflit script/EA
- ✅ Nettoyage automatique toutes les 5 minutes
- ✅ Stats ML temps réel depuis AWS RDS

---

## 🔧 Modifications Apportées

### 1. Include ajouté (ligne 16)
```mql5
#include "GOM_Enhanced_Dashboard.mqh"  // Dashboard ML AWS RDS
```

### 2. Nouveau paramètre (ligne 84)
```mql5
input bool UseEnhancedDashboard = true; // Tableau de bord ML AWS RDS (compact, stats temps réel)
```

### 3. Fonction UpdateDashboard() modifiée (ligne ~14049)
```mql5
void UpdateDashboard()
{
   // Afficher le nouveau dashboard ML AWS RDS (prioritaire)
   if(UseEnhancedDashboard)
   {
      // Nettoyage automatique toutes les 5 minutes
      static datetime lastCleanupTime = 0;
      if(TimeCurrent() - lastCleanupTime >= 300)
      {
         GOM_CleanExpiredDrawings();
         lastCleanupTime = TimeCurrent();
      }

      // Afficher le dashboard
      GOM_DrawEnhancedDashboard();
      return;
   }
   
   // ... ancien code si dashboard désactivé
}
```

### 4. OnDeinit() modifié (ligne ~11047)
```mql5
// Nettoyer le dashboard amélioré
if(UseEnhancedDashboard)
   GOM_CleanEnhancedDashboard();
```

### 5. Fichiers copiés dans MT5

**Emplacements:**
```
Terminal\F016FF5B93786543B564E81A925D7066\MQL5\
├── Scripts\GOM_Enhanced_Dashboard.mqh
├── Include\GOM_Enhanced_Dashboard.mqh
└── Experts\Free Robots\SMC_Universal\GOM_Enhanced_Dashboard.mqh

Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\
├── Scripts\GOM_Enhanced_Dashboard.mqh
├── Include\GOM_Enhanced_Dashboard.mqh
└── Experts\Free Robots\SMC_Universal\GOM_Enhanced_Dashboard.mqh
```

---

## 🚀 Installation Rapide

### Étape 1: Synchroniser les fichiers

**Option A: Script automatique (recommandé)**
```
Double-cliquez: sync_dashboard_to_mt5.bat
```

**Option B: Manuel**
```bash
cd D:\Dev\TradBOT\
cp GOM_Enhanced_Dashboard.mqh "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\Experts\Free Robots\SMC_Universal\"
```

### Étape 2: Compiler SMC_Universal

1. Ouvrez **MetaEditor**
2. Ouvrez `SMC_Universal.mq5`
3. Appuyez sur **F7** (Compiler)
4. Vérifiez: **0 error(s)** ✅

### Étape 3: Lancer la synchronisation ML

```bash
cd D:\Dev\TradBOT\
python sync_ml_stats_to_mt5.py
```
**OU** double-cliquez: `start_ml_sync.bat`

### Étape 4: Attacher SMC_Universal

1. Dans **MT5**, glissez `SMC_Universal` sur un graphique
2. Dans les paramètres:
   - Section: **MODULE SIDO (FIGURES CHARTISTES)**
   - ✅ `UseEnhancedDashboard = true`
3. Cliquez **OK**

### Étape 5: Vérifier le Dashboard

Après ~30 secondes, vous devriez voir en **bas à gauche**:

```
🤖 ACTIVE    📊 POS:X     💵 +X.XX$
🎯 XX.X%     📈 XX.X%     🧠 x36
🔮 XXs       📊 XXXX      💼 XXX
```

---

## 📊 Dashboard Affiche

### Ligne 1: Statut Robot
| Cellule | Description | Couleurs |
|---------|-------------|----------|
| 🤖 ACTIVE | Robot en mode trading | Vert |
| ⏸️ PAUSE | Pause après profit target | Orange |
| ⏸️ STOPPED | Robot arrêté | Gris |
| 📊 POS:2 | Positions ouvertes | Bleu |
| 💵 +2.45$ | Profit journalier | Vert/Rouge |

### Ligne 2: Info Pause (si en pause)
| Cellule | Description |
|---------|-------------|
| TARGET HIT | Raison (objectif atteint) |
| ⏱️ 2h30m | Temps restant avant reprise |

### Ligne 3: Stats ML
| Cellule | Description | Couleurs |
|---------|-------------|----------|
| 🎯 68.2% | Précision ML | Vert ≥65%, Orange ≥55%, Rouge <55% |
| 📈 64.0% | Win rate trades | Vert ≥60%, Orange ≥50%, Rouge <50% |
| 🧠 x36 | Modèles chargés | Bleu |

### Ligne 4: Activité
| Cellule | Description | Couleurs |
|---------|-------------|----------|
| 🔮 15s | Dernière prédiction | Vert <2min, Orange <10min, Rouge >10min |
| 📊 1247 | Total prédictions | Gris |
| 💼 89 | Total trades | Gris |

---

## 🔄 Flux de Données

```
AWS RDS PostgreSQL
    ↓
sync_ml_stats_to_mt5.py (30s refresh)
    ↓
MT5 GlobalVariables
    ↓
SMC_Universal.mq5 (lit GV)
    ↓
GOM_DrawEnhancedDashboard()
    ↓
Dashboard visible sur le graphique
```

---

## 🧹 Nettoyage Automatique

### Objets nettoyés
- ✅ Lignes de tendance > 4h
- ✅ Objets expirés (OBJPROP_TIME < now)
- ✅ Préfixes: GOM_, DASH_, KOLA_, SIDO_

### Fréquence
- Toutes les **5 minutes** (au lieu de 10 minutes avant)
- Fonction: `GOM_CleanExpiredDrawings()`

### Impact
- ✅ Prévient l'accumulation d'objets
- ✅ Maintient les performances
- ✅ Garde les niveaux récents seulement

---

## ⚙️ Configuration

### Position du Dashboard

Par défaut: **Bas gauche (10, 10)**

Pour changer, modifiez dans `GOM_Enhanced_Dashboard.mqh` (ligne ~250):
```mql5
int baseX = 10;   // Distance depuis le bord gauche
int baseY = 10;   // Distance depuis le bord bas
```

### Taille Police

Par défaut: **7** (compact, lisible)

Pour changer:
```mql5
int fontSize = 7;  // 7 = compact, 9 = normal, 11 = grand
```

### Couleurs

Material Design (flat, moderne):
```mql5
color bgDark = 0x1E1E1E;    // Gris foncé
color bgGreen = 0x2E7D32;   // Vert mat
color bgRed = 0xC62828;     // Rouge mat
color bgOrange = 0xEF6C00;  // Orange
color bgBlue = 0x1565C0;    // Bleu mat
```

### Fréquence Rafraîchissement

Dans SMC_Universal.mq5 (ligne ~13512):
```mql5
if(currentTime - lastDashboardUpdate >= 15)  // 15 secondes
{
   lastDashboardUpdate = currentTime;
   UpdateDashboard();
}
```

---

## 🐛 Dépannage

### Problème 1: Compilation échoue

**Erreur:** `file 'GOM_Enhanced_Dashboard.mqh' not found`

**Solution:**
```bash
# Lancer sync_dashboard_to_mt5.bat
# OU copier manuellement:
copy D:\Dev\TradBOT\GOM_Enhanced_Dashboard.mqh "C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\Experts\Free Robots\SMC_Universal\"
```

### Problème 2: Dashboard n'apparaît pas

**Vérifications:**
1. ✅ SMC_Universal attaché au graphique
2. ✅ `UseEnhancedDashboard = true` dans les paramètres
3. ✅ `sync_ml_stats_to_mt5.py` en cours d'exécution

**Solution:**
- Redémarrer l'EA (Supprimer → Ré-attacher)
- Vérifier les logs MT5: onglet "Experts"

### Problème 3: Stats ML à 0

**Cause:** Script Python pas lancé

**Solution:**
```bash
cd D:\Dev\TradBOT\
python sync_ml_stats_to_mt5.py
```

**Vérifier:**
- Logs montrent "Synchronisation terminée"
- Connexion AWS RDS réussie
- GlobalVariables créées (Tools → Options → Expert Advisors)

### Problème 4: Dashboard désactivé par défaut

**Si `UseEnhancedDashboard = false`:**
1. Clic droit sur graphique → Expert Advisors → Liste
2. Sélectionnez SMC_Universal → Propriétés
3. Onglet "Paramètres d'entrée"
4. Cherchez `UseEnhancedDashboard`
5. Changez en `true`
6. OK

---

## 📈 Performances

### Impact CPU
- **Dashboard seul:** < 1% CPU
- **Nettoyage (5min):** < 0.5% CPU (spike court)
- **Sync Python (30s):** < 2% CPU

### Mémoire
- **Dashboard:** ~50 KB (12 objets graphiques)
- **GlobalVariables:** ~1 KB (14 variables)
- **Total:** Négligeable

### Réseau
- **AWS RDS → Python:** ~5 KB/req (toutes les 30s)
- **Python → MT5:** Local (pas de réseau)

---

## 🔐 Sécurité

### GlobalVariables
- ✅ Lecture seule depuis MQ5
- ✅ Écriture uniquement par script Python autorisé
- ✅ Pas d'exposition externe

### Connexion AWS RDS
- ✅ SSL/TLS obligatoire
- ✅ Credentials depuis .env (pas hardcodés)
- ✅ Timeout connexion: 30s

---

## 📝 Fichiers Impliqués

### Source
```
D:\Dev\TradBOT\
├── GOM_Enhanced_Dashboard.mqh      (417 lignes)
├── SMC_Universal.mq5               (modifié)
├── sync_ml_stats_to_mt5.py         (226 lignes)
├── start_ml_sync.bat               (22 lignes)
└── sync_dashboard_to_mt5.bat       (57 lignes)
```

### MT5 Terminal
```
C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\
├── F016FF5B93786543B564E81A925D7066\MQL5\
│   └── Experts\Free Robots\SMC_Universal\
│       ├── SMC_Universal.mq5
│       ├── SMC_Universal.ex5
│       └── GOM_Enhanced_Dashboard.mqh
└── E6E3D0917DD641581E4779524EB3B1AA\MQL5\
    └── Experts\Free Robots\SMC_Universal\
        └── GOM_Enhanced_Dashboard.mqh
```

---

## ✅ Checklist Déploiement

Avant de démarrer le trading:

- [ ] `GOM_Enhanced_Dashboard.mqh` synchronisé (run `sync_dashboard_to_mt5.bat`)
- [ ] `SMC_Universal.mq5` compilé sans erreur (0 error(s))
- [ ] `sync_ml_stats_to_mt5.py` en cours d'exécution
- [ ] Connexion AWS RDS validée (logs "Synchronisation terminée")
- [ ] SMC_Universal attaché au graphique
- [ ] `UseEnhancedDashboard = true` dans les paramètres
- [ ] Dashboard visible bas gauche du graphique
- [ ] Stats ML affichent des valeurs > 0 après 30s

---

## 🎯 Prochaines Étapes

### Court terme
1. ✅ Compiler SMC_Universal avec dashboard
2. ✅ Tester localement avec sync Python
3. ⏳ Vérifier déploiement Render (AWS RDS)

### Moyen terme
1. Ajouter graphique historique profit (courbe)
2. Alertes push MT5 si win rate < 50%
3. Export stats CSV automatique

### Long terme
1. Dashboard web externe (Streamlit)
2. API REST pour récupérer stats ML
3. Backtesting automatique avec métriques

---

## 📞 Support

**Fichiers à vérifier en cas de problème:**
- MT5 Logs: Onglet "Experts"
- Python Logs: Console `sync_ml_stats_to_mt5.py`
- AWS RDS: CloudWatch logs (optionnel)

**Commandes utiles:**
```bash
# Tester connexion AWS RDS
python test_aws_rds_connection.py

# Relancer sync
python sync_ml_stats_to_mt5.py

# Synchroniser fichiers MT5
sync_dashboard_to_mt5.bat

# Vérifier GlobalVariables
# Dans MT5: Tools → Options → Expert Advisors → Global Variables
```

---

**Version:** 1.0.0  
**Date:** 2026-05-15  
**Auteur:** TradBOT Team
