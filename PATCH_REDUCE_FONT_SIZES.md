# Patch - Réduction des tailles de police dans SMC_Universal.mq5

## 🎨 Objectif
Réduire toutes les polices (OBJPROP_FONTSIZE) pour un affichage graphique moins encombré et plus professionnel.

---

## 📝 Modifications à apporter

### Rechercher et remplacer dans SMC_Universal.mq5

#### 1. Labels OTE Setup (ligne ~71, ~78, ~85, ~93)

**AVANT:**
```mql5
ObjectSetInteger(0, entryLabel, OBJPROP_FONTSIZE, 10);
ObjectSetInteger(0, slLabel, OBJPROP_FONTSIZE, 9);
ObjectSetInteger(0, tpLabel, OBJPROP_FONTSIZE, 9);
ObjectSetInteger(0, title, OBJPROP_FONTSIZE, 12);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, entryLabel, OBJPROP_FONTSIZE, 7);
ObjectSetInteger(0, slLabel, OBJPROP_FONTSIZE, 7);
ObjectSetInteger(0, tpLabel, OBJPROP_FONTSIZE, 7);
ObjectSetInteger(0, title, OBJPROP_FONTSIZE, 8);
```

---

#### 2. Labels Stair Setup (ligne ~227, ~234)

**AVANT:**
```mql5
ObjectSetInteger(0, entryLabel, OBJPROP_FONTSIZE, 10);
ObjectSetInteger(0, title, OBJPROP_FONTSIZE, 12);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, entryLabel, OBJPROP_FONTSIZE, 7);
ObjectSetInteger(0, title, OBJPROP_FONTSIZE, 8);
```

---

#### 3. Labels BOS/CHOCH (ligne ~271, ~319)

**AVANT:**
```mql5
ObjectSetInteger(0, bosLabel, OBJPROP_FONTSIZE, 11);
ObjectSetInteger(0, chochLabel, OBJPROP_FONTSIZE, 11);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, bosLabel, OBJPROP_FONTSIZE, 8);
ObjectSetInteger(0, chochLabel, OBJPROP_FONTSIZE, 8);
```

---

#### 4. Panel HMS (ligne ~940)

**AVANT:**
```mql5
ObjectSetInteger(0, panelName, OBJPROP_FONTSIZE, 8);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, panelName, OBJPROP_FONTSIZE, 7);
```

---

#### 5. Labels divers (ligne ~2457)

**AVANT:**
```mql5
ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 7);
```

---

#### 6. Statistics Display (ligne ~3319)

**AVANT:**
```mql5
ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 7);
```

---

#### 7. Spike Labels (ligne ~9930, ~9945)

**AVANT:**
```mql5
ObjectSetInteger(0, spikeName, OBJPROP_FONTSIZE, 12);
ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_FONTSIZE, 14);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, spikeName, OBJPROP_FONTSIZE, 9);
ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_FONTSIZE, 10);
```

---

#### 8. Entry/SL Markers (ligne ~10181, ~10209)

**AVANT:**
```mql5
ObjectSetInteger(0, shName, OBJPROP_FONTSIZE, 10);
ObjectSetInteger(0, slName, OBJPROP_FONTSIZE, 10);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, shName, OBJPROP_FONTSIZE, 8);
ObjectSetInteger(0, slName, OBJPROP_FONTSIZE, 8);
```

---

#### 9. ICT Premium/Discount Labels (ligne ~11382, ~11391, ~11400, ~11424)

**AVANT:**
```mql5
ObjectSetInteger(0, "SMC_ICT_PREMIUM_LABEL", OBJPROP_FONTSIZE, 9);
ObjectSetInteger(0, "SMC_ICT_DISCOUNT_LABEL", OBJPROP_FONTSIZE, 9);
ObjectSetInteger(0, "SMC_ICT_EQUILIBRE_LABEL", OBJPROP_FONTSIZE, 8);
ObjectSetInteger(0, "SMC_ICT_CORRECTION_LABEL", OBJPROP_FONTSIZE, 9);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, "SMC_ICT_PREMIUM_LABEL", OBJPROP_FONTSIZE, 7);
ObjectSetInteger(0, "SMC_ICT_DISCOUNT_LABEL", OBJPROP_FONTSIZE, 7);
ObjectSetInteger(0, "SMC_ICT_EQUILIBRE_LABEL", OBJPROP_FONTSIZE, 7);
ObjectSetInteger(0, "SMC_ICT_CORRECTION_LABEL", OBJPROP_FONTSIZE, 7);
```

---

#### 10. High/Low Labels (ligne ~15957, ~15978)

**AVANT:**
```mql5
ObjectSetInteger(0, highLabelName, OBJPROP_FONTSIZE, 10);
ObjectSetInteger(0, lowLabelName, OBJPROP_FONTSIZE, 10);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, highLabelName, OBJPROP_FONTSIZE, 8);
ObjectSetInteger(0, lowLabelName, OBJPROP_FONTSIZE, 8);
```

---

#### 11. Countdown Display (ligne ~25457)

**AVANT:**
```mql5
ObjectSetInteger(0, countdownName, OBJPROP_FONTSIZE, 13);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, countdownName, OBJPROP_FONTSIZE, 9);
```

---

#### 12. SMC_OTE Zone Labels (ligne ~26274, ~26340)

**AVANT:**
```mql5
ObjectSetInteger(0, pfx + "BUY_LBL", OBJPROP_FONTSIZE, 9);
ObjectSetInteger(0, pfx + "SELL_LBL", OBJPROP_FONTSIZE, 9);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, pfx + "BUY_LBL", OBJPROP_FONTSIZE, 7);
ObjectSetInteger(0, pfx + "SELL_LBL", OBJPROP_FONTSIZE, 7);
```

---

#### 13. Probability Text (ligne ~27120)

**AVANT:**
```mql5
ObjectSetInteger(0, probTextName, OBJPROP_FONTSIZE, 12);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, probTextName, OBJPROP_FONTSIZE, 9);
```

---

#### 14. Status Text (ligne ~27189)

**AVANT:**
```mql5
ObjectSetInteger(0, statusTextName, OBJPROP_FONTSIZE, 10);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, statusTextName, OBJPROP_FONTSIZE, 8);
```

---

#### 15. Buy/Sell Arrows (ligne ~30043, ~30065)

**AVANT:**
```mql5
ObjectSetInteger(0, buyLabel, OBJPROP_FONTSIZE, 12);
ObjectSetInteger(0, sellLabel, OBJPROP_FONTSIZE, 12);
```

**APRÈS:**
```mql5
ObjectSetInteger(0, buyLabel, OBJPROP_FONTSIZE, 9);
ObjectSetInteger(0, sellLabel, OBJPROP_FONTSIZE, 9);
```

---

## 🔧 Script de remplacement automatique

Si vous préférez utiliser un script bash pour automatiser:

```bash
#!/bin/bash

# Backup du fichier original
cp "D:\Dev\TradBOT\SMC_Universal.mq5" "D:\Dev\TradBOT\SMC_Universal.mq5.backup"

# Remplacements
sed -i 's/OBJPROP_FONTSIZE, 14/OBJPROP_FONTSIZE, 10/g' "D:\Dev\TradBOT\SMC_Universal.mq5"
sed -i 's/OBJPROP_FONTSIZE, 13/OBJPROP_FONTSIZE, 9/g' "D:\Dev\TradBOT\SMC_Universal.mq5"
sed -i 's/OBJPROP_FONTSIZE, 12/OBJPROP_FONTSIZE, 9/g' "D:\Dev\TradBOT\SMC_Universal.mq5"
sed -i 's/OBJPROP_FONTSIZE, 11/OBJPROP_FONTSIZE, 8/g' "D:\Dev\TradBOT\SMC_Universal.mq5"
sed -i 's/OBJPROP_FONTSIZE, 10/OBJPROP_FONTSIZE, 8/g' "D:\Dev\TradBOT\SMC_Universal.mq5"
sed -i 's/OBJPROP_FONTSIZE, 9/OBJPROP_FONTSIZE, 7/g' "D:\Dev\TradBOT\SMC_Universal.mq5"

echo "✅ Toutes les polices ont été réduites!"
```

---

## ✅ Vérification

Après application du patch:

1. **Compiler** le fichier pour vérifier aucune erreur
2. **Charger** sur graphique de test
3. **Observer** l'affichage:
   - Labels plus discrets
   - Graphique moins encombré
   - Lisibilité conservée

---

## 📊 Tableau récapitulatif des changements

| Élément | Avant | Après | Réduction |
|---------|-------|-------|-----------|
| Spike Warning | 14pt | 10pt | -29% |
| Countdown | 13pt | 9pt | -31% |
| Titres principaux | 12pt | 9pt | -25% |
| Labels moyens | 10pt | 8pt | -20% |
| Labels standards | 9pt | 7pt | -22% |
| Labels petits | 8pt | 7pt | -12% |

**Moyenne**: -23% de réduction sur toutes les polices

---

## 🎯 Impact visuel attendu

### Avant
```
┌─────────────────────────────────┐
│  ⚡ OTE SETUP - BUY ⚡           │  ← Police 12pt
│  OTE Entry BUY @1.09850         │  ← Police 10pt
│  SL: 1.09800                    │  ← Police 9pt
│  TP: 1.09950                    │  ← Police 9pt
└─────────────────────────────────┘
```

### Après
```
┌───────────────────────────┐
│ ⚡ OTE SETUP - BUY ⚡      │  ← Police 8pt
│ Entry @1.09850            │  ← Police 7pt
│ SL: 1.09800               │  ← Police 7pt
│ TP: 1.09950               │  ← Police 7pt
└───────────────────────────┘
```

**Gain**: 30% moins d'espace vertical occupé

---

## 💡 Recommandations additionnelles

### 1. Réduire longueur des labels

Dans `DrawOTESetup()`, remplacer:
```mql5
ObjectSetString(0, entryLabel, OBJPROP_TEXT, "OTE Entry " + direction + " @" + DoubleToString(entryPrice, _Digits));
```

Par:
```mql5
ObjectSetString(0, entryLabel, OBJPROP_TEXT, direction + " @" + DoubleToString(entryPrice, _Digits));
```

### 2. Augmenter transparence

Dans les rectangles OTE, passer de:
```mql5
ObjectSetInteger(0, entryZone, OBJPROP_BACK, true);
```

À:
```mql5
ObjectSetInteger(0, entryZone, OBJPROP_BACK, true);
ObjectSetInteger(0, entryZone, OBJPROP_FILL, true);
// Ajouter transparence via couleur ARGB
color transparentColor = 0x5A0000FF; // Alpha=90, Couleur=Bleu
ObjectSetInteger(0, entryZone, OBJPROP_COLOR, transparentColor);
```

### 3. Utiliser symboles au lieu de texte

Remplacer:
```mql5
"⚡ OTE SETUP - BUY ⚡"  // 21 caractères
```

Par:
```mql5
"⬆ OTE BUY"  // 9 caractères (-57%)
```

---

## ⚠️ Notes importantes

1. **Lisibilité**: Testez sur votre écran - si trop petit, ajustez à 8pt au lieu de 7pt
2. **Résolution**: Sur écrans 4K, les polices 7pt restent lisibles
3. **Cohérence**: Gardez la même taille pour le même type d'info
4. **Backup**: Toujours sauvegarder avant modification massive

---

**Version**: 1.0
**Date**: 2026-04-28
**Compatibilité**: SMC_Universal.mq5 (toutes versions)
