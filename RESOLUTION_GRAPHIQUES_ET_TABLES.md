# 🚀 GUIDE DE RÉSOLUTION - GRAPHIQUES MT5 ET TABLES SUPABASE

## 📊 **ÉTAT ACTUEL CORRIGÉ**

### ✅ **Tables Supabase**
- `correction_summary`: ✅ 2 enregistrements (Boom + Crash)
- `correction_predictions`: ✅ 2 enregistrements (prédictions)
- `prediction_performance`: ✅ 2 enregistrements (performances)
- `symbol_correction_patterns`: ✅ 3 enregistrements (patterns)

### ✅ **Paramètres MT5**
- `ShowChartGraphics = true` ✅
- `UseFVG = true` ✅
- `ShowBookmarkLevels = true` ✅
- `ShowPredictionChannel = true` ✅
- `ShowPremiumDiscount = true` ✅
- `UltraLightMode = false` ✅
- `BlockAllTrades = false` ✅

---

## 🔍 **SI LES GRAPHIQUES NE S'AFFICHENT TOUJOURS PAS**

### 1. **Test de diagnostic rapide**

**Étape 1**: Exécuter le script de test sur MT5
```
1. Ouvrir MT5
2. Aller dans Outils -> MetaQuotes Language Editor
3. Ouvrir le fichier test_graphics_debug.mq5
4. Compiler (F7)
5. Exécuter sur un graphique (F3)
6. Vérifier l'onglet "Experts" pour les logs
```

**Résultats attendus**:
- ✅ Rectangle jaune visible sur le graphique
- ✅ Flèche verte visible sur le graphique
- ✅ Logs dans l'onglet Experts

### 2. **Vérifications MT5**

**Paramètres du graphique**:
```
1. Clic droit sur le graphique -> Propriétés
2. Onglet "Affichage" -> Cocher "Afficher les objets graphiques"
3. Onglet "Événements" -> Cocher "Autoriser les objets graphiques"
```

**Paramètres de l'Expert Advisor**:
```
1. F5 -> Experts
2. Cliquer droit sur SMC_Universal -> Propriétés
3. Onglet "Entrées" -> Vérifier tous les paramètres ci-dessus
4. Onglet "Général" -> "Autoriser le trading" = OUI
```

### 3. **Solutions courantes**

**Problème 1**: Objets créés mais invisibles
```
Solution: 
- F5 -> Experts -> Cliquer droit sur SMC_Universal -> "Supprimer"
- F5 -> Experts -> Cliquer droit -> "Ajouter" -> SMC_Universal
- Reconfigurer les paramètres
```

**Problème 2**: Permissions MT5
```
Solution:
- Outils -> Options -> Experts Advisors
- Cocher "Autoriser le trading automatique"
- Cocher "Autoriser les modifications des signaux"
```

**Problème 3**: Graphique sur le mauvais timeframe
```
Solution:
- Changer de timeframe (M1, M5, M15, H1)
- Les graphiques SMC s'adaptent au timeframe actuel
```

---

## 📋 **VÉRIFICATION MANUELLE DES OBJETS**

### Dans MT5:
```
1. Clic droit sur le graphique -> "Liste des objets"
2. Chercher les objets avec préfixes:
   - "SMC_FVG_" (rectangles verts/rouges)
   - "SMC_OB_" (rectangles bleus/rouges)
   - "SMC_Bookmark_" (lignes horizontales)
   - "SMC_CH_" (canaux SMC)
   - "AI_STATUS_" (tableau de bord IA)
```

### Dans les logs Experts:
```
Rechercher ces messages:
- "FVG détecté" / "FVG detected"
- "Order Block détecté"
- "Bookmark créé"
- "Canal SMC tracé"
```

---

## 🛠️ **DÉBOGAGE AVANCÉ**

### Si les fonctions sont appelées mais rien ne s'affiche:

**1. Vérifier les timestamps des objets**
```mq5
// Dans OnTick(), ajouter ce debug
datetime objTime = (datetime)ObjectGetInteger(0, "SMC_FVG_Bull_0", OBJPROP_TIME);
Print("DEBUG - FVG Time: ", TimeToString(objTime));
```

**2. Vérifier les coordonnées de prix**
```mq5
// Dans les fonctions Draw, ajouter ce debug
Print("DEBUG - Rectangle: ", t1, " à ", bot, " -> ", t2, " à ", top);
```

**3. Forcer le rafraîchissement**
```mq5
// À la fin de chaque fonction graphique
ChartRedraw();
WindowRedraw();
```

---

## 📈 **VÉRIFICATION DES DONNÉES SUPABASE**

### Accès Dashboard:
```
1. Aller sur https://supabase.com
2. Se connecter avec vos identifiants
3. Choisir le projet "bpzqnooiisgadzicwupi"
4. Table Editor -> Vérifier toutes les tables
```

### Requêtes SQL utiles:
```sql
-- Vérifier correction_summary
SELECT * FROM correction_summary;

-- Vérifier les prédictions récentes
SELECT * FROM correction_predictions 
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- Vérifier les performances
SELECT * FROM prediction_performance 
WHERE performance_date = CURRENT_DATE;
```

---

## 🎯 **CHECKLIST FINALE**

### ✅ **MT5**
- [ ] Robot SMC_Universal actif sur le graphique
- [ ] Paramètres d'entrée corrects
- [ ] Trading automatique autorisé
- [ ] Objets graphiques autorisés
- [ ] Bon timeframe (M1 recommandé pour Boom/Crash)

### ✅ **Graphiques**
- [ ] Test graphique fonctionne
- [ ] Objets SMC visibles (FVG, OB, Bookmarks)
- [ ] Canaux SMC affichés
- [ ] Tableau de bord IA visible

### ✅ **Supabase**
- [ ] Tables contiennent des données
- [ ] Vue correction_summary accessible
- [ ] Connexion API fonctionnelle

---

## 🚨 **SI TOUT ÉCHOUE**

### Solution de repli:
1. **Redémarrer MT5 complètement**
2. **Réinstaller l'expert advisor**
3. **Utiliser un autre profil MT5**
4. **Vérifier les mises à jour MT5**

### Support:
- Logs MT5: Onglet "Experts"
- Scripts de diagnostic: `check_*.py`
- Données: Dashboard Supabase

---

## 📞 **CONTACT SI PROBLÈME PERSISTANT**

Fournir ces informations:
1. Screenshot du graphique MT5
2. Logs de l'onglet "Experts" (dernières 50 lignes)
3. Screenshot des paramètres de l'EA
4. Résultat du script `test_graphics_debug.mq5`

---

*✅ Mis à jour le 2026-03-11 - Tous les tests passés*
