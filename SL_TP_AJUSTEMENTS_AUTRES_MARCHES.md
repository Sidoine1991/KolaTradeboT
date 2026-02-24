# Ajustement des SL/TP pour les autres marchés

## Problème identifié
Les Stop Loss et Take Profit étaient trop serrés pour les autres marchés (Forex, indices, matières premières), causant des sorties prématurées.

## Modifications apportées

### 1. Fonction `CalculateSLTP()` (lignes 10633-10638)
**Avant :**
- SL: 2x ATR
- TP: 3x ATR

**Après :**
- SL: 4x ATR (augmenté de 2x)
- TP: 8x ATR (augmenté de ~2.7x)

### 2. Fallback points fixes (lignes 10671-10675)
**Avant :**
- SL: 50 points
- TP: 100 points

**Après :**
- SL: 150 points (augmenté de 3x)
- TP: 300 points (augmenté de 3x)

### 3. Fonction `CalculateSLTPInPointsWithMaxLoss()` (lignes 3585-3586)
**Avant :**
- SL additionnel: 30 points
- TP additionnel: 50 points

**Après :**
- SL additionnel: 100 points (augmenté de ~3.3x)
- TP additionnel: 200 points (augmenté de 4x)

## Résumé par type de marché

### Boom/Crash (inchangé)
- SL: 500 points / 10x ATR
- TP: 1000 points / 15x ATR
- Additionnel: 300/600 points

### Volatility (inchangé)
- SL: 100 points / 3x ATR
- TP: 200 points / 5x ATR

### Autres marchés **(AJUSTÉ)**
- SL: 150 points / 4x ATR (auparavant 50/2x)
- TP: 300 points / 8x ATR (auparavant 100/3x)
- Additionnel: 100/200 points (auparavant 30/50)

## Impact attendu
- **Moins de sorties prématurées** sur Forex, indices et matières premières
- **Meilleur ratio risque/rendement** pour les marchés moins volatils
- **Plus de temps** pour que les trades se développent
- **Réduction** des faux signaux causés par une volatilité normale

## Fonctions non modifiées (déjà correctes)
- `ExecuteAutoLimitOrder()`: utilise déjà 300/600 points
- Ordres Boom/Crash: déjà paramétrés avec des distances appropriées
