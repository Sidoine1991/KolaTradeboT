# Explication: Pause Automatique UTC

**Date:** 2026-05-16 00:45  
**Sujet:** Pourquoi le robot est en pause et quand reprendra-t-il ?

---

## 🔍 Ce que montrent les logs

```
⏸ MODE ARRÊT AUTO UTC - Trading suspendu hors fenêtres (heure UTC=23)
```

Le robot est en **pause automatique UTC** car:
1. La perte journalière a atteint **-20 USD** ou plus
2. L'heure actuelle (UTC 23h = 00h locale) est **hors des fenêtres autorisées**

---

## ⚙️ Fonctionnement du Mode UTC

### Condition d'activation

Le mode strict UTC s'active **uniquement** si:
- Perte journalière globale ≥ 20 USD
- **OU** perte flottante + perte réalisée ≥ 20 USD

### Fenêtres de trading autorisées (UTC)

Le robot ne trade que pendant ces créneaux UTC:

**Fenêtre 1:** TradeWindow1StartUTC → TradeWindow1EndUTC  
**Fenêtre 2:** TradeWindow2StartUTC → TradeWindow2EndUTC  
**Fenêtre 3:** TradeWindow3StartUTC → TradeWindow3EndUTC

(Vérifiez vos inputs dans MT5 pour les valeurs exactes)

### En dehors de ces fenêtres

✅ **Autorisé:**
- Surveillance des graphiques
- Appels IA
- Mise à jour du dashboard
- Calcul des niveaux GOM/KOLA/SIDO

❌ **Bloqué:**
- Ouverture de nouvelles positions
- Modification d'ordres existants
- Fermeture automatique de positions

---

## 📊 Dashboard ML - Nouveau Statut

Le dashboard affiche maintenant:

```
┌───────────────────────────────────┐
│ ⏸️ UTC PAUSE  📊 POS:0  💵 -20.45$ │
│ ⏰ Hors fenêtre UTC    ↻ ATTENTE   │
│ 🎯 68.2%   📈 64.0%   🧠 x36       │
│ 🔮 15s     📊 1247    💼 89        │
└───────────────────────────────────┘
```

**Ligne 1:**
- `⏸️ UTC PAUSE` (fond orange) = Robot en pause UTC
- `📊 POS:0` = 0 positions ouvertes
- `💵 -20.45$` (fond rouge) = Perte journalière qui a déclenché le mode strict

**Ligne 2:**
- `⏰ Hors fenêtre UTC` = En dehors des créneaux autorisés
- `↻ ATTENTE` = Attend prochaine fenêtre

---

## 🕐 Quand le robot reprendra-t-il ?

### Reprise automatique

Le robot reprendra **automatiquement** quand:
1. L'heure UTC entre dans une des 3 fenêtres configurées
2. **ET** la perte journalière reste ≥ -20 USD

### Reprise immédiate

Le robot reprend **immédiatement** si:
- La perte journalière remonte au-dessus de -20 USD
- (Exemple: positions gagnantes qui réduisent la perte globale)

---

## 📈 Vérifier l'État Actuel

### Dans MT5

1. Ouvrir le graphique avec SMC_Universal attaché
2. Regarder le dashboard en haut à gauche
3. Statut = `⏸️ UTC PAUSE` → Pause active

### Dans les logs (onglet Experts)

Cherchez:
```
⏸ MODE ARRÊT AUTO UTC - Trading suspendu hors fenêtres (heure UTC=XX)
```

Le log apparaît toutes les 60 secondes quand le mode est actif.

### Vérifier fenêtres configurées

1. MT5 → Navigateur → Expert Advisors → SMC_Universal
2. Clic droit → Propriétés
3. Onglet "Inputs"
4. Chercher section "**FENÊTRES UTC STRICTES**"
5. Noter:
   - `UseStrictUTCTradeWindows` = true/false
   - `TradeWindow1StartUTC` = XX
   - `TradeWindow1EndUTC` = YY
   - (idem pour Window2 et Window3)

---

## 🔧 Ajuster les Fenêtres (si nécessaire)

Si vous voulez **élargir** les fenêtres de trading:

1. Supprimez l'EA du graphique
2. Re-glissez SMC_Universal
3. Dans les inputs, modifiez:
   ```
   TradeWindow1StartUTC = 6   (exemple: 6h UTC = 7h locale)
   TradeWindow1EndUTC = 12    (exemple: 12h UTC = 13h locale)
   
   TradeWindow2StartUTC = 14
   TradeWindow2EndUTC = 20
   
   TradeWindow3StartUTC = 0
   TradeWindow3EndUTC = 4
   ```

4. Cliquez OK

### ⚠️ Désactiver complètement le mode strict

Pour trader **24/7 même en perte**:

```
UseStrictUTCTradeWindows = false
```

**Attention:** Cela supprime la protection contre les pertes continues.

---

## 🎯 Pourquoi ce Mode Existe

### Protection du capital

Le mode strict UTC protège contre:
- **Overtrading** pendant les pertes
- **Revenge trading** émotionnel
- **Spirale descendante** de pertes

### Heures optimales

Les fenêtres UTC configurées correspondent généralement à:
- Sessions Londres (08h-12h UTC)
- Sessions New York (14h-20h UTC)
- Moments de forte liquidité

### Psychologie

Forcer une pause après -20 USD permet:
- Réévaluation de la stratégie
- Éviter les décisions impulsives
- Protéger le compte d'une série de pertes

---

## 📌 GlobalVariables Utilisées

Le dashboard lit ces variables (mises à jour par SMC_Universal):

| Variable | Valeur | Signification |
|----------|--------|---------------|
| `EA_DASH_UTC_PAUSE` | 1.0 | Pause UTC active |
| `EA_DASH_UTC_PAUSE` | 0.0 | Trading normal (fenêtre ouverte) |
| `ROBOT_DAILY_PROFIT` | -20.45 | Perte journalière actuelle |

Vous pouvez les voir dans:
MT5 → Tools → Options → Expert Advisors → Global Variables

---

## ✅ Modifications Apportées (2026-05-16)

### SMC_Universal.mq5

**Ligne ~13590:** Ajout GlobalVariable pause UTC
```cpp
// Indiquer au dashboard que le robot est en pause UTC
GlobalVariableSet("EA_DASH_UTC_PAUSE", 1.0);
```

**Ligne ~13621:** Réactivation quand fenêtre ouverte
```cpp
// Fenêtre UTC ouverte: réactiver le trading
GlobalVariableSet("EA_DASH_UTC_PAUSE", 0.0);
```

### GOM_Enhanced_Dashboard.mqh

**Ligne ~131:** Ajout champ `utcWindowPause`
```cpp
bool utcWindowPause;       // Pause UTC hors fenêtres autorisées
```

**Ligne ~172:** Lecture de la GlobalVariable
```cpp
status.utcWindowPause = (GlobalVariableCheck("EA_DASH_UTC_PAUSE") &&
                         GlobalVariableGet("EA_DASH_UTC_PAUSE") > 0.5);
```

**Ligne ~247:** Affichage statut "UTC PAUSE"
```cpp
if(robot.utcWindowPause)
{
   statusTxt = "⏸️ UTC PAUSE";
   statusBg = bgOrange;
}
```

**Ligne ~274:** Ligne d'info pause UTC
```cpp
if(robot.utcWindowPause)
{
   GOM_DrawDashCell("DASH_UTC_REASON", baseX, baseY + row * (cellH + gap),
                    cellW * 2 + gap, cellH, "⏰ Hors fenêtre UTC", bgOrange, txtWhite, fontSize - 1, anchorTop);
   // ...
}
```

---

## 🚀 Prochaines Étapes

1. **Recompiler** SMC_Universal.mq5 dans MetaEditor (F7)
2. **Supprimer** l'EA du graphique
3. **Re-attacher** SMC_Universal
4. **Vérifier** le dashboard affiche "⏸️ UTC PAUSE"

Le dashboard vous indiquera maintenant **clairement** quand le robot est en pause UTC et pourquoi.

---

**Version:** 1.0.0  
**Auteur:** TradBOT Team  
**Date:** 2026-05-16 00:45
