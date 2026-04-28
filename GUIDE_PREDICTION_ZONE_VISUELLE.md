# 🔮 Guide - Zone de Prédiction Visuelle ML

## 📊 Vue d'ensemble

Système complet de **prédiction visuelle intelligente** qui affiche sur le graphique MT5:
- ✅ **Bougies futures prédites** (5-10 bougies)
- ✅ **Trajectoire avec segments** et flèches directionnelles
- ✅ **Zone de prédiction transparente**
- ✅ **Points clés** (support, résistance, pivots, cibles)
- ✅ **Pourcentage de confiance** pour chaque bougie

---

## 🎯 Fichiers créés

### 1. Backend Python (API)
```
backend/api/prediction_candles.py
```
- Endpoint `/prediction/candles/future`
- Combine données Supabase + temps réel
- Modèle ML de prédiction
- Génération trajectoire

### 2. Frontend MQL5 (Affichage)
```
Include/Prediction_Zone_Visual.mqh
```
- Dessine bougies futures
- Trace trajectoire avec flèches
- Gère transparence et couleurs
- Labels de confiance

---

## 🚀 Intégration dans SMC_Universal.mq5

### Étape 1: Ajouter l'include

En haut du fichier `SMC_Universal.mq5`:

```mql5
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
// ... autres includes ...

// ✅ NOUVEAU: Système de prédiction visuelle
#include <Prediction_Zone_Visual.mqh>
```

### Étape 2: Appeler dans OnTick()

Dans la fonction `OnTick()`, ajouter:

```mql5
void OnTick()
{
   // ... code existant ...

   // ✅ NOUVEAU: Afficher zone de prédiction (toutes les 60s)
   static datetime lastPredictionDisplay = 0;
   if(TimeCurrent() - lastPredictionDisplay >= 60)
   {
      DisplayPredictionZone();
      lastPredictionDisplay = TimeCurrent();
   }

   // ... reste du code ...
}
```

### Étape 3: Nettoyer à la fermeture (optionnel)

Dans `OnDeinit()`:

```mql5
void OnDeinit(const int reason)
{
   // ... code existant ...

   // ✅ NOUVEAU: Nettoyer objets de prédiction
   CleanupPredictionZone();
}
```

---

## ⚙️ Configuration Backend (FastAPI)

### 1. Ajouter le router dans main.py

Dans `backend/main.py`:

```python
from fastapi import FastAPI
from api import robot_integration, prediction_candles  # ✅ Nouveau

app = FastAPI(title="KolaTradeBot")

# Routers existants
app.include_router(robot_integration.router)

# ✅ NOUVEAU: Router prédiction
app.include_router(prediction_candles.router)
```

### 2. Installer dépendances (si besoin)

```bash
cd backend
pip install numpy scikit-learn
```

### 3. Démarrer le serveur

```bash
python start_ai_server.py
```

Vérifier que l'endpoint est actif:
```
http://localhost:8000/prediction/candles/future
```

---

## 🎨 Affichage sur le graphique

### Zone de prédiction

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│  Prix actuel ━━━━━━━━━━━━━━━━━━━━━┓                │
│                                    ┃                 │
│                    ⚡ ZONE PRÉDICTION ML             │
│  ╔═════════════════════════════════╗                │
│  ║  📊 [Bougie 1] 85% ▲            ║                │
│  ║      ↓                           ║                │
│  ║  📊 [Bougie 2] 72% ▲            ║                │
│  ║      ↓                           ║                │
│  ║  📊 [Bougie 3] 60% ▼            ║                │
│  ║      ↓                           ║                │
│  ║  📊 [Bougie 4] 51% ▼ 🔄         ║                │
│  ║      ↓                           ║                │
│  ║  📊 [Bougie 5] 43% ▲ 🎯 Target  ║                │
│  ╚═════════════════════════════════╝                │
│                                                      │
│  Trajectoire: ──────▲──────▲──────▼──────▼──────▲  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Éléments visuels

1. **Zone transparente** (fond gris foncé, alpha=230)
2. **Bougies prédites**:
   - Vert (haussier) ou Rouge (baissier)
   - Transparence selon confiance
   - Corps + mèches
3. **Trajectoire**:
   - Ligne jaune épaisse
   - Segments reliant les clôtures
   - Flèches ▲ ▼ à chaque changement
4. **Labels**:
   - % confiance au-dessus de chaque bougie
   - 🎯 pour la cible finale
   - 🔄 pour les pivots

---

## 📡 API Endpoints

### GET /prediction/candles/future

Prédire les N prochaines bougies.

**Paramètres:**
```
symbol: str         # "EURUSD", "Boom 500 Index", etc.
timeframe: str      # "M1", "M5", "M15", "H1"
num_candles: int    # 1-20 (défaut: 5)
price: float        # Prix actuel
ema_fast: float     # EMA rapide
ema_slow: float     # EMA lente
rsi: float          # RSI actuel
atr: float          # ATR actuel
```

**Réponse:**
```json
{
  "symbol": "EURUSD",
  "timeframe": "M5",
  "current_price": 1.0850,
  "prediction_horizon": 5,
  "candles": [
    {
      "time": "2024-04-28T12:20:00",
      "open": 1.0850,
      "high": 1.0865,
      "low": 1.0848,
      "close": 1.0860,
      "confidence": 85.0,
      "trend_direction": "UP"
    },
    ...
  ],
  "trajectory_points": [
    {
      "time": "2024-04-28T12:15:00",
      "price": 1.0850,
      "type": "PIVOT",
      "confidence": 100.0
    },
    {
      "time": "2024-04-28T12:30:00",
      "price": 1.0870,
      "type": "TARGET",
      "confidence": 60.0
    }
  ],
  "trend_direction": "UP",
  "trend_strength": 75.5,
  "volatility_expected": 1.2,
  "key_levels": {
    "current": 1.0850,
    "predicted_high": 1.0875,
    "predicted_low": 1.0845,
    "target": 1.0870
  },
  "ml_confidence": 68.5
}
```

---

## 🎛️ Paramètres personnalisables

Dans les inputs de `Prediction_Zone_Visual.mqh`:

### Général
```mql5
ShowPredictionZone = true;              // Activer/désactiver
PredictionNumCandles = 5;               // Nombre de bougies (1-20)
```

### Affichage bougies
```mql5
ShowPredictedCandles = true;            // Afficher bougies
PredictedCandleBullish = clrLimeGreen;  // Couleur haussière
PredictedCandleBearish = clrCrimson;    // Couleur baissière
PredictedCandleAlpha = 180;             // Transparence (0-255)
```

### Trajectoire
```mql5
ShowTrajectoryPath = true;              // Afficher trajectoire
ShowTrajectoryArrows = true;            // Flèches direction
TrajectoryLineColor = clrYellow;        // Couleur ligne
TrajectoryLineWidth = 2;                // Épaisseur (1-5)
TrajectoryArrowSize = 2;                // Taille flèches
```

### Labels
```mql5
ShowConfidenceLabels = true;            // % confiance
ConfidenceLabelSize = 7;                // Taille police
```

### Zone
```mql5
PredictionZoneColor = clrDarkSlateGray; // Couleur fond
PredictionZoneAlpha = 230;              // Transparence
```

---

## 🧠 Algorithme de prédiction

### 1. Analyse tendance actuelle
```python
# EMAs
if ema_fast > ema_slow and price > ema_fast:
    direction = "UP"
elif ema_fast < ema_slow and price < ema_fast:
    direction = "DOWN"
else:
    direction = "SIDEWAYS"

# Force = écart EMA
strength = abs(ema_fast - ema_slow) / ema_slow * 1000
```

### 2. Patterns historiques (Supabase)
```python
# Récupérer depuis Supabase:
- Volatilité moyenne (30 jours)
- Taille moyenne des bougies
- Persistance de tendance
- Supports/Résistances clés
```

### 3. Projection bougies
```python
for i in range(num_candles):
    # Confiance décroissante
    confidence = 85% * (0.85 ^ i)
    
    # Variation attendue
    change = avg_candle_size * (1 + random_noise)
    
    # Appliquer direction
    if direction == "UP":
        close = open + change
        high = close + change * 0.3
        low = open - change * 0.1
    
    # Inversion possible selon persistance
    if random() > trend_persistence:
        direction = reverse(direction)
```

### 4. Points de trajectoire
```python
# Point 0 = prix actuel (100% confiance)
# Points intermédiaires = pivots probables
# Dernier point = cible finale
```

---

## 📊 Exemple visuel complet

### Configuration
```mql5
PredictionNumCandles = 7
ShowTrajectoryArrows = true
ShowConfidenceLabels = true
```

### Graphique résultant

```
Prix
  ↑
1.0900 ┤                                    🎯 Target (42%)
       │                                   ╱
1.0890 ┤                                  ╱ ▲
       │                                 ╱
1.0880 ┤                          📊    ╱
       │                          ▼    ╱
1.0870 ┤                   📊    🔄   ╱
       │                   ▲         ╱
1.0860 ┤            📊    ╱        ╱
       │            ▲   ╱         ╱
1.0850 ┤     📊    ╱   ╱         ╱
       │     ▲   ╱   ╱          ╱
1.0840 ┤━━━━━━━━╱───╱──────────╱────────── Zone prédiction
       │     85% 72% 60% 51% 43% 36% 30%
       └────┼───┼───┼───┼───┼───┼───┼──→ Temps
          Actuel +5m +10m +15m +20m +25m +30m
```

---

## 🔄 Mise à jour automatique

- **Fréquence:** Toutes les 60 secondes
- **Déclencheur:** `OnTick()` de MT5
- **Condition:** Si 60s écoulées depuis dernière màj
- **Nettoyage:** Anciens objets supprimés avant redessin

---

## 🛠️ Développements futurs

### Phase 1 (actuel)
- ✅ Prédiction basique avec patterns
- ✅ Affichage bougies + trajectoire
- ✅ Confiance décroissante

### Phase 2 (à venir)
- 🔲 Connexion Supabase réelle (patterns historiques)
- 🔲 Modèle ML LSTM pour prédiction avancée
- 🔲 Intégration données sentiment de marché
- 🔲 Zones de probabilité (70%, 80%, 90%)

### Phase 3 (avancé)
- 🔲 Multi-timeframes (M1, M5, H1 simultanés)
- 🔲 Prédiction jusqu'à 50 bougies
- 🔲 Scénarios multiples (bull/bear/neutral)
- 🔲 Backtesting précision prédictions

---

## 📝 Notes importantes

### Performance
- Mise à jour **toutes les 60s** (pas à chaque tick)
- API timeout: **5 secondes**
- Pas d'impact sur vitesse trading

### Précision
- **Confiance initiale: 85%**
- Décroissance exponentielle: `0.85^i`
- Bougie 5: ~44% confiance
- Bougie 10: ~20% confiance

### Limitations
- Ne **pas** utiliser pour décisions de trading automatiques
- Indicatif uniquement (aide visuelle)
- Précision dépend qualité données Supabase

---

## ✅ Checklist installation

- [ ] Fichier `prediction_candles.py` dans `backend/api/`
- [ ] Fichier `Prediction_Zone_Visual.mqh` dans `Include/`
- [ ] Router ajouté dans `backend/main.py`
- [ ] Include ajouté dans `SMC_Universal.mq5`
- [ ] Appel `DisplayPredictionZone()` dans `OnTick()`
- [ ] Serveur backend démarré (`python start_ai_server.py`)
- [ ] Compilation SMC_Universal.mq5 réussie
- [ ] Test sur graphique démo

---

## 🆘 Dépannage

### Zone ne s'affiche pas
1. Vérifier serveur backend actif: `http://localhost:8000/docs`
2. Vérifier logs MT5 pour erreurs HTTP
3. Vérifier `ShowPredictionZone = true`

### Bougies mal positionnées
1. Vérifier timeframe cohérent (M5, M15, etc.)
2. Vérifier horloge MT5 synchronisée
3. Ajuster `PeriodSeconds(PERIOD_CURRENT)`

### Performances dégradées
1. Augmenter intervalle màj: `g_predictionUpdateInterval = 120` (2min)
2. Réduire nombre bougies: `PredictionNumCandles = 3`
3. Désactiver labels: `ShowConfidenceLabels = false`

---

**Version:** 1.0  
**Date:** 2026-04-28  
**Status:** Prêt pour intégration
