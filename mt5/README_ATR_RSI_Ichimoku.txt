# ATR_RSI_Ichimoku_Combined - Indicateur pour Boom/Crash

## Description
Indicateur technique combiné qui affiche l'ATR, le RSI et l'Ichimoku dans une seule fenêtre séparée. Conçu spécifiquement pour le trading sur les indices Boom et Crash.

## Caractéristiques

### Indicateurs inclus :
- **RSI** (14 périodes) : Ligne bleue avec niveaux 30/70
- **ATR** (14 périodes) : Ligne rouge, mise à l'échelle 0-100
- **Ichimoku** :
  - Tenkan-sen (9) : Ligne bleue
  - Kijun-sen (26) : Ligne rouge  
  - Senkou Span A : Ligne verte
  - Senkou Span B : Ligne orange
  - Chikou Span : Ligne violette
- **Signaux de trading** : Flèches jaunes

### Signaux de trading générés :

#### Signaux d'achat (BUY) :
- RSI croise au-dessus de 30 (survente)
- Tenkan-sen croise au-dessus de Kijun-sen (Ichimoku haussier)
- Combinaison : RSI > 50 ET Tenkan > Kijun

#### Signaux de vente (SELL) :
- RSI croise en dessous de 70 (surachat)
- Tenkan-sen croise en dessous de Kijun-sen (Ichimoku baissier)
- Combinaison : RSI < 50 ET Tenkan < Kijun

## Installation

1. Copiez le fichier `ATR_RSI_Ichimoku_Combined.mq5` dans :
   ```
   C:\Users\VOTRE_NOM\AppData\Roaming\MetaQuotes\Terminal\[TERMINAL_ID]\MQL5\Indicators\
   ```

2. Redémarrez MetaTrader 5

3. Dans le navigateur d'indicateurs, trouvez "ATR_RSI_Ichimoku_Combined"

4. Glissez-déposez sur le graphique Boom ou Crash

## Paramètres

### RSI Settings
- `RSI_Period` : Période RSI (défaut: 14)
- `RSI_Price` : Type de prix (défaut: PRICE_CLOSE)
- `RSI_Overbought` : Niveau surachat (défaut: 70.0)
- `RSI_Oversold` : Niveau survente (défaut: 30.0)

### ATR Settings
- `ATR_Period` : Période ATR (défaut: 14)

### Ichimoku Settings
- `Tenkan` : Période Tenkan-sen (défaut: 9)
- `Kijun` : Période Kijun-sen (défaut: 26)
- `SenkouB` : Période Senkou Span B (défaut: 52)

### Display Settings
- `ShowRSI` : Afficher RSI (défaut: true)
- `ShowATR` : Afficher ATR (défaut: true)
- `ShowIchimoku` : Afficher Ichimoku (défaut: true)
- `ShowSignals` : Afficher les signaux (défaut: true)
- `SignalMultiplier` : Multiplicateur pour ATR (défaut: 2.0)

## Utilisation avec Boom/Crash

### Pour Boom (indices haussiers) :
- Recherchez les signaux d'achat
- Confirmez avec RSI < 50 ou croissement haussier Ichimoku
- L'ATR élevé indique une forte volatilité (bon pour entrées)

### Pour Crash (indices baissiers) :
- Recherchez les signaux de vente
- Confirmez avec RSI > 50 ou croissement baissier Ichimoku
- L'ATR faible peut indiquer une phase de calme avant un mouvement

## Interprétation

### Échelle 0-100 :
- **0-30** : Zone de survente (potentiel d'achat pour Boom)
- **30-70** : Zone neutre
- **70-100** : Zone de surachat (potentiel de vente pour Crash)

### Combinaisons optimales :
1. **Boom** : RSI < 30 + Tenkan > Kijun + ATR modéré
2. **Crash** : RSI > 70 + Tenkan < Kijun + ATR élevé

## Avantages

- **Vue d'ensemble** : Tous les indicateurs importants dans une fenêtre
- **Signaux clairs** : Flèches jaunes pour les points d'entrée
- **Adapté** : Spécialement conçu pour la volatilité de Boom/Crash
- **Personnalisable** : Paramètres ajustables selon votre style

## Dépannage

Si l'indicateur ne s'affiche pas :
1. Vérifiez que le fichier est dans le bon dossier
2. Redémarrez MT5
3. Compilez l'indicateur dans MetaEditor
4. Vérifiez les erreurs dans l'onglet "Experts"

## Notes

- L'ATR est mis à l'échelle pour s'afficher dans la même fenêtre que le RSI
- Les signaux sont générés automatiquement mais doivent être confirmés par l'analyse
- Idéal pour une utilisation avec le robot F_INX_robot4.mq5
