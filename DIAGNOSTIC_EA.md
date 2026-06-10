# 🔍 DIAGNOSTIC : EA ne montre pas GOM TV

## ✅ ÉTAPE 1 : Vérifier que l'EA tourne

**Sur MetaTrader 5 :**

1. **Regarde en haut à droite du graphique**
   - Tu dois voir une **icône souriante** 😊
   - Si tu vois 😞 ou ❌ → EA pas actif

2. **Si EA pas actif :**
   - Clique sur "AutoTrading" (bouton vert en haut)
   - Ré-attache l'EA : Navigateur (Ctrl+N) → Experts → deriveapro → glisse sur le graphique

3. **Paramètres EA obligatoires :**
   ```
   InpDebug = true  ← TRÈS IMPORTANT
   ```

---

## ✅ ÉTAPE 2 : Vérifier les logs

**Ouvre les logs Expert :**
```
1. Ctrl+T (Boîte à outils)
2. Onglet "Expert"
3. Cherche les lignes avec "[v10]" ou "[DerivEAPro"
```

**Copie-colle ici les 20 dernières lignes qui commencent par "[v10]" ou "[DerivEAPro"**

---

## ✅ ÉTAPE 3 : Vérifier le symbole

**L'EA est-il attaché sur le BON graphique ?**

Sur le graphique MT5 :
- En haut à gauche, tu dois voir : **"Boom 500 Index, M1"**
- Si tu vois autre chose (Boom 1000, Crash, etc.) → Mauvais graphique

---

## ✅ ÉTAPE 4 : Forcer le rechargement

**Dans MT5 :**
```
1. Clique-droit sur le graphique
2. "Expert Advisors" → "Remove"
3. Attends 3 secondes
4. Ré-attache deriveapro depuis Navigateur
5. Configure InpDebug = true
6. OK
```

---

## ✅ ÉTAPE 5 : Vérifier que l'EA lit le fichier

**Logs attendus au démarrage :**

**SANS GOM TV (au démarrage initial) :**
```
[DerivEAPro v10.04] ✅ Init | Boom 500 Index | SMC=ON | ...
[v10] ⚠️  GOM TV non disponible au démarrage (GOM poller lancé?)
```

**AVEC GOM TV (après polling) :**
```
[v10] ✅ GOM TV init: Boom500Index | verdict=PERFECT BUY | quality=43%
[v10] 🎯 GOM TV: PERFECT BUY (q=43%) | imbalance=0.00 | liquidity=0.00
```

**Si tu vois des erreurs comme :**
```
[v10] ⚠️  GOM TV: fichier non trouvé D:\Dev\TradBOT\data\gom_signal.json
[v10] GOM TV: symbole mismatch (EA=Boom 500 Index, TV=XAUUSD)
```

→ Dis-moi quelle erreur tu vois !

---

## ✅ ÉTAPE 6 : Vérifier le dashboard

**Le dashboard est-il visible ?**

En haut à gauche du graphique, tu dois voir du texte :
```
-- DerivEAPro v10.04 -- Boom 500 Index --
Regime=... SL=... TP=...
Bal $... | Eq $... | Pos:0
```

**Si tu ne vois RIEN du tout :**
1. Vérifie que le graphique n'est pas en mode "Masquer tous les objets"
2. Clique-droit → Propriétés → Onglet "Général" → Décoche "Masquer les objets"

---

## 🐛 PROBLÈMES FRÉQUENTS

### Problème 1 : "GOM TV: symbole mismatch"

**Log :**
```
[v10] GOM TV: symbole mismatch (EA=Boom 500 Index, TV=Boom500Index)
```

**Cause :** Le nom dans `gom_signal.json` ne correspond pas exactement.

**Solution :** Dis-moi "Le symbole ne correspond pas", je vais fixer le fichier.

---

### Problème 2 : "fichier non trouvé"

**Log :**
```
[v10] ⚠️  GOM TV: fichier non trouvé D:\Dev\TradBOT\data\gom_signal.json
```

**Cause :** MT5 ne trouve pas le fichier (mauvais chemin).

**Solution :** Vérifie que le fichier existe :
```
1. Ouvre l'explorateur Windows
2. Va dans D:\Dev\TradBOT\data\
3. Cherche gom_signal.json
4. S'il existe → copie le chemin complet et dis-moi
```

---

### Problème 3 : Dashboard vide mais EA tourne

**Symptôme :** Icône 😊 mais aucun texte visible

**Cause :** Objets graphiques masqués

**Solution :**
```
1. Clique-droit sur le graphique
2. Propriétés
3. Onglet "Général"
4. Décoche "Masquer les objets graphiques"
5. OK
```

---

## 📸 CE QUE TU DEVRAIS VOIR

**Dashboard complet (exemple) :**
```
┌────────────────────────────────────────────────┐
│ -- DerivEAPro v10.04 -- Boom 500 Index --     │
│ Regime=TRENDING SL=1.5×ATR TP=2.5×ATR | ...   │
│ Bal $1000.00 | Eq $1000.00 | Pos:0 | ...     │
│ Z=1.2  RSI=66  ATR=8.5  Stair=50%  ...       │
│ Imminence [||||......] 40%                     │
│ Barres: 5/12 (42%) | Spread: 5                │
│                                                │
│ GHOST: PERFECT BUY | delta=92.89 | buyPct=24% │
│ GOM TV: FRESH (3s) | imbalance=0.00 | ...    │
│ Setup TV BUY: Entry=5011.79 SL=5010.82 ...   │
└────────────────────────────────────────────────┘
```

**Si tu vois ça mais SANS les 3 dernières lignes (GHOST/GOM TV/Setup)** → L'EA ne lit pas le fichier.

---

## 🆘 AIDE RAPIDE

**Envoie-moi :**

1. **Screenshot du graphique MT5** (montre-moi ce que tu vois)

2. **Les 20 dernières lignes des logs Expert** qui contiennent `[v10]`

3. **Réponds à ces questions :**
   - L'icône EA est-elle 😊 ou 😞 ?
   - Vois-tu DU TOUT du texte en haut à gauche ?
   - Quel symbole est affiché sur le graphique ?
   - InpDebug est-il à `true` ?

**Je t'aiderai immédiatement après !** 🚀
