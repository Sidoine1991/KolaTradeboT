# 🚀 INSTALLATION DU SCANNER MULTI-SYMBOLES

## ✅ Fichiers Créés

### 1. Code Source
- ✅ **SMC_OpportunityScanner.mqh** (26 KB) - Classe du scanner
- ✅ **SMC_Universal.mq5** (modifié) - Intégration du scanner

### 2. Documentation
- ✅ **SCANNER_OPPORTUNITES_README.md** - Guide complet d'utilisation
- ✅ **SCANNER_VISUAL_GUIDE.md** - Guide visuel avec exemples
- ✅ **test_scanner.txt** - Instructions de test

## 📦 Fichiers Automatiquement Copiés dans MT5

Les fichiers ont été automatiquement copiés ici:
```
C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts\
```

Fichiers:
- ✅ SMC_OpportunityScanner.mqh
- ✅ SMC_Universal.mq5

## 🔧 Étapes d'Installation

### Étape 1: Compiler le Robot
1. Ouvrir **MetaTrader 5**
2. Appuyer sur **F4** pour ouvrir MetaEditor
3. Dans le Navigator (gauche), aller dans: **Experts → SMC_Universal.mq5**
4. Cliquer droit → **Compile** (ou appuyer sur F7)
5. Vérifier qu'il n'y a **aucune erreur** (les warnings sont normaux)

**Résultat attendu:**
```
0 errors, 2 warnings
SMC_Universal.ex5 generated
```

### Étape 2: Vérifier la Compilation
Si vous voyez des erreurs, vérifier:
1. Les deux fichiers sont dans le bon dossier
2. Redémarrer MetaEditor
3. Recompiler

### Étape 3: Configurer les Symboles
1. Ouvrir un graphique pour **chaque symbole** à surveiller:
   - Boom 1000 Index
   - Crash 1000 Index  
   - Volatility 75 Index
   - EURUSD
   - etc.

2. Sur **chaque graphique**, attacher **SMC_Universal** (glisser depuis Navigator)

### Étape 4: Activer le Scanner
Sur **UN SEUL graphique** (par exemple EURUSD):

1. Ouvrir les paramètres du robot (cliquer droit → Propriétés)
2. Aller dans l'onglet **Entrées**
3. Trouver la section **"SCANNER MULTI-SYMBOLES TEMPS RÉEL"**
4. Configurer:

```
EnableOpportunityScanner = true
ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,Volatility 75 Index,EURUSD,GBPUSD"
ScannerRefreshSeconds = 2
ScannerPanelX = 10
ScannerPanelY = 30
ScannerPanelWidth = 500
ScannerRowHeight = 25
ScannerShowPanel = true
```

5. Cliquer **OK**

### Étape 5: Vérification
Après quelques secondes, vous devriez voir:
- Un panneau en haut du graphique
- Titre: "🔶 SCANNER OPPORTUNITÉS TEMPS RÉEL"
- Liste des opportunités (si disponibles)

## 🎯 Configuration Recommandée

### Setup Minimal (2 Graphiques)
```
Graphique 1: Boom 1000 Index
- Robot SMC_Universal attaché
- Scanner DÉSACTIVÉ

Graphique 2: Crash 1000 Index  
- Robot SMC_Universal attaché
- Scanner ACTIVÉ avec liste: "Boom 1000 Index,Crash 1000 Index"
```

### Setup Optimal (4-6 Graphiques)
```
Graphique 1: Boom 1000 Index (robot actif)
Graphique 2: Crash 1000 Index (robot actif)
Graphique 3: Volatility 75 Index (robot actif)
Graphique 4: EURUSD (robot actif)
Graphique 5: GBPUSD (robot actif + SCANNER ACTIVÉ)

ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,Volatility 75 Index,EURUSD,GBPUSD"
```

Le graphique 5 affichera toutes les opportunités des 5 symboles.

### Setup Complet (8-10 Graphiques)
```
+ XAUUSD
+ Step Index
+ Volatility 100 Index
+ USDJPY
+ AUDUSD

ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,Volatility 75 Index,Volatility 100 Index,Step Index,EURUSD,GBPUSD,XAUUSD,USDJPY,AUDUSD"
```

**⚠️ Attention:** Plus de 10 symboles peut ralentir MT5.

## 🔍 Dépannage

### Problème: "file not found" lors de la compilation
**Solution:**
1. Vérifier que `SMC_OpportunityScanner.mqh` est dans:
   - `C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\...\MQL5\Experts\`
   - OU `MQL5\Include\`

2. Copier manuellement le fichier si nécessaire
3. Redémarrer MetaEditor
4. Recompiler

### Problème: Panneau scanner ne s'affiche pas
**Solutions:**
1. Vérifier que `EnableOpportunityScanner = true`
2. Vérifier que `ScannerShowPanel = true`
3. Vérifier que le robot tourne (icône souriante en haut à droite)
4. Attendre 5-10 secondes après le démarrage

### Problème: Aucune opportunité affichée
**Solutions:**
1. Vérifier que les **robots tournent** sur les autres graphiques
2. Vérifier que les **noms des symboles** sont exacts (case sensitive)
3. Attendre quelques minutes que les données se mettent à jour
4. Vérifier les Global Variables (Outils → Global Variables):
   - Chercher: `GOM_SCRIPT_Boom 1000 Index_VERDICT_NUM`
   - Si absente: le robot ne publie pas les données

### Problème: Le panneau est mal positionné
**Solution:**
Ajuster dans les paramètres:
```
ScannerPanelX = 10      // Plus grand = vers la droite
ScannerPanelY = 30      // Plus grand = vers le bas
ScannerPanelWidth = 500 // Largeur du panneau
```

### Problème: MT5 ralentit
**Solutions:**
1. Réduire le nombre de symboles surveillés (max 8)
2. Augmenter l'intervalle: `ScannerRefreshSeconds = 3` ou `5`
3. Fermer les graphiques non utilisés
4. Désactiver le scanner temporairement

## 📊 Vérification de Bon Fonctionnement

### Test Rapide
1. Attacher le robot sur Boom 1000 Index avec scanner actif
2. Dans ScannerSymbolsList: "Boom 1000 Index"
3. Après 5 secondes, le panneau devrait montrer:
   - Titre visible
   - Timestamp qui s'actualise
   - Une ligne avec Boom 1000 (si setup détecté) OU message "Aucune opportunité"

### Test Complet
1. Attacher sur Boom 1000 + Crash 1000
2. Scanner sur liste: "Boom 1000 Index,Crash 1000 Index"
3. Vérifier que les 2 symboles apparaissent (si setups valides)

### Vérification Global Variables
1. Dans MT5: **Outils → Global Variables**
2. Chercher: `GOM_SCRIPT_`
3. Vous devriez voir pour chaque symbole:
   - `GOM_SCRIPT_Boom 1000 Index_VERDICT_NUM`
   - `GOM_SCRIPT_Boom 1000 Index_BUY_ENTRY`
   - `GOM_SCRIPT_Boom 1000 Index_SELL_ENTRY`
   - `GOM_SCRIPT_Boom 1000 Index_SPIKE_PROB`
   - etc.

Si ces variables existent → le robot publie correctement
Si absentes → problème avec le robot (pas le scanner)

## 🎓 Prochaines Étapes

### 1. Lire la Documentation
- ✅ **SCANNER_OPPORTUNITES_README.md** - Comprendre toutes les fonctionnalités
- ✅ **SCANNER_VISUAL_GUIDE.md** - Apprendre à lire le panneau

### 2. Tester en Démo
- Activer le scanner en compte démo
- Observer pendant 1-2 jours
- Comprendre les patterns

### 3. Optimiser la Configuration
- Trouver les meilleurs symboles pour votre style
- Ajuster la position/taille du panneau
- Configurer les alertes

### 4. Utiliser en Réel
- Une fois maîtrisé le scanner
- Commencer avec 2-3 symboles
- Augmenter progressivement

## 📞 Support

### Logs MT5
Pour diagnostiquer un problème:
1. Onglet **Experts** (en bas de MT5)
2. Chercher les messages du robot
3. Noter les erreurs éventuelles

### Informations Utiles à Fournir
Si vous rencontrez un problème:
- Version MT5
- Message d'erreur exact
- Configuration du scanner (inputs)
- Symboles utilisés
- Capture d'écran

## ✅ Checklist de Validation

Avant de demander de l'aide, vérifier:

- [ ] SMC_Universal.mq5 compile sans erreur
- [ ] Le fichier .ex5 est généré
- [ ] Le robot est attaché sur les graphiques
- [ ] EnableOpportunityScanner = true
- [ ] ScannerShowPanel = true
- [ ] Les noms des symboles sont corrects
- [ ] Le robot tourne (icône souriante)
- [ ] Attente de 10-15 secondes minimum
- [ ] Global Variables présentes (GOM_SCRIPT_...)
- [ ] Documentation lue

## 🎉 Félicitations!

Si vous voyez le panneau scanner avec des opportunités, **c'est réussi**! 🎊

Le scanner surveille maintenant en temps réel tous vos symboles et affiche les meilleures opportunités.

**Bon trading!** 📈🚀

---

**Développé par TradBOT SMC** - Scanner d'opportunités professionnel
**Date:** 2026-05-14
**Version:** 1.0
