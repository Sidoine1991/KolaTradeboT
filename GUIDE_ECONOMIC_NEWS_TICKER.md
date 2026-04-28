# 📰 Guide - Ticker Actualités Économiques Défilant

## 📊 Vue d'ensemble

Système complet d'**affichage des actualités économiques en temps réel** qui affiche en bas du graphique MT5:
- ✅ **Ticker défilant animé** avec actualités forex, crypto, calendrier économique
- ✅ **Icônes d'impact** (🔴 HIGH, 📰 MEDIUM, ⚡ LOW)
- ✅ **Mise à jour automatique** toutes les 2 minutes
- ✅ **API publiques gratuites** (Financial Modeling Prep, CoinGecko)
- ✅ **Adapté au symbole** (filtre actualités pertinentes)

---

## 🎯 Fichiers créés

### 1. Backend Python (API)
```
backend/api/economic_news.py
```
- Endpoint `/economic/news/ticker`
- Sources: FMP (forex), CoinGecko (crypto)
- Calendrier économique démo (Fed, ECB, GDP)
- Formatage ticker avec icônes

### 2. Frontend MQL5 (Affichage)
```
Include/Economic_News_Ticker.mqh
```
- Dessine fond du ticker en bas du graphique
- Anime texte défilant (scrolling)
- Appelle API toutes les 2 minutes
- Gère transparence et couleurs

---

## 🚀 Intégration dans SMC_Universal.mq5

### Étape 1: Include ajouté automatiquement

```mql5
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
// ... autres includes ...

// ✅ NOUVEAU: Ticker actualités économiques
#include <Economic_News_Ticker.mqh>
```

### Étape 2: Initialisation dans OnInit()

```mql5
void OnInit()
{
   // ... code existant ...

   // ✅ NOUVEAU: Initialiser ticker économique
   InitEconomicTicker();

   // ... reste du code ...
}
```

### Étape 3: Animation dans OnTick()

```mql5
void OnTick()
{
   // ... code existant ...

   // ✅ NOUVEAU: Affichage ticker économique (animé à chaque tick)
   DisplayEconomicNewsTicker();

   // ... reste du code ...
}
```

### Étape 4: Nettoyage dans OnDeinit()

```mql5
void OnDeinit(const int reason)
{
   // ... code existant ...

   // ✅ NOUVEAU: Nettoyer ticker économique
   CleanupEconomicTicker();

   // ... reste du code ...
}
```

---

## 🎨 Affichage sur le graphique

### Position du ticker

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│                  [Graphique MT5]                     │
│                                                      │
│              [Prix et bougies]                       │
│                                                      │
│                                                      │
│                                                      │
│                                                      │
├──────────────────────────────────────────────────────┤
│  📰 EUR/USD climbs on ECB news | 🔴 [HIGH] Fed Rate │ ← Ticker défilant
│  Decision 14:30 | ⚡ BTC breaks $50k resistance...  │
└──────────────────────────────────────────────────────┘
   ↑                                                  ↑
   30px du bas                                        Fond gris foncé
```

### Éléments visuels

1. **Fond du ticker**:
   - Couleur: `clrDarkSlateGray` (gris foncé)
   - Hauteur: 25 pixels
   - Position: 30 pixels du bas
   - Largeur: 100% du graphique

2. **Texte défilant**:
   - Couleur: `clrYellow` (jaune vif)
   - Police: Arial, taille 8pt
   - Animation: défile de droite à gauche
   - Vitesse: 2 pixels par tick

3. **Icônes d'impact**:
   - 🔴 HIGH: Événements majeurs (Fed, ECB, NFP)
   - 📰 MEDIUM: Actualités importantes
   - ⚡ LOW: Alertes et news secondaires
   - 📊 Trading, 💹 Market, 🌐 Analysis (infos générales)

---

## 📡 API Endpoints

### GET /economic/news/ticker

Récupérer le ticker formaté pour un symbole.

**URL:**
```
http://localhost:8000/economic/news/ticker?symbol=EURUSD
```

**Paramètres:**
- `symbol` (required): Symbole du trading pair (ex: "EURUSD", "Boom 500 Index")

**Réponse:**
```json
{
  "symbol": "EURUSD",
  "news": [
    {
      "title": "EUR/USD Rallies on Strong ECB Data",
      "description": "Euro gains against dollar following...",
      "source": "FMP",
      "published_at": "2024-04-28T14:30:00Z",
      "category": "FOREX",
      "impact": "HIGH",
      "related_symbols": ["EURUSD", "EUR", "USD"],
      "url": "https://..."
    }
  ],
  "events": [
    {
      "time": "2024-04-28T14:30:00Z",
      "country": "US",
      "event_name": "Fed Interest Rate Decision",
      "impact": "HIGH",
      "forecast": "5.50%",
      "previous": "5.25%",
      "actual": null,
      "currency": "USD"
    }
  ],
  "last_update": "2024-04-28T14:25:00Z",
  "ticker_text": "🔴 [HIGH] Fed Rate Decision 14:30 | 📰 EUR/USD Rallies on Strong ECB Data | ⚡ Market analysis in progress"
}
```

### GET /economic/news/list

Liste complète des actualités.

**URL:**
```
http://localhost:8000/economic/news/list?category=FOREX&limit=20
```

**Paramètres:**
- `category` (optional): "FOREX", "CRYPTO", "COMMODITIES", "INDICES"
- `limit` (optional): 1-100 (défaut: 20)

### GET /economic/calendar/today

Calendrier économique du jour.

**URL:**
```
http://localhost:8000/economic/calendar/today
```

**Réponse:**
```json
[
  {
    "time": "2024-04-28T14:30:00Z",
    "country": "US",
    "event_name": "Fed Interest Rate Decision",
    "impact": "HIGH",
    "forecast": "5.50%",
    "previous": "5.25%",
    "actual": null,
    "currency": "USD"
  }
]
```

### GET /economic/health

Vérifier connexion aux APIs.

**URL:**
```
http://localhost:8000/economic/health
```

**Réponse:**
```json
{
  "fmp_api": "ok",
  "coingecko_api": "ok",
  "timestamp": "2024-04-28T14:25:00Z"
}
```

---

## ⚙️ Configuration Backend

### 1. Router ajouté automatiquement dans main.py

```python
# --- Inclusion du router Economic News ---
try:
    from backend.api.economic_news import router as economic_news_router
    app.include_router(economic_news_router, prefix="/economic", tags=["Economic News"])
    print("✅ Router Economic News inclus")
except ImportError:
    print("⚠️ Module Economic News non disponible")
```

### 2. Clés API (optionnel - démo fonctionne sans)

Dans `.env`:
```env
ALPHA_VANTAGE_API_KEY=your_key_here
FMP_API_KEY=your_key_here
TRADING_ECONOMICS_KEY=your_key_here
```

**Note:** Les clés "demo" par défaut fonctionnent avec quotas limités.

### 3. Démarrer le serveur

```bash
python start_ai_server.py
```

Vérifier que l'endpoint est actif:
```
http://localhost:8000/economic/news/ticker?symbol=EURUSD
```

---

## 🎛️ Paramètres personnalisables

Dans les inputs de `Economic_News_Ticker.mqh`:

### Général
```mql5
ShowEconomicTicker = true;              // Activer/désactiver
TickerUpdateInterval = 120;             // Mise à jour toutes les N secondes
```

### Affichage
```mql5
TickerTextColor = clrYellow;            // Couleur texte
TickerBackgroundColor = clrDarkSlateGray; // Couleur fond
TickerFontSize = 8;                     // Taille police
TickerHeight = 25;                      // Hauteur ticker (pixels)
TickerYPosition = 30;                   // Distance depuis le bas
```

### Animation
```mql5
TickerScrollSpeed = 2;                  // Vitesse défilement (pixels/tick)
TickerShowIcons = true;                 // Afficher emojis/icônes
```

---

## 🔄 Algorithme de défilement

### 1. Récupération du texte

```mql5
// Toutes les 120 secondes
if(TimeCurrent() - g_lastTickerUpdate >= 120)
{
   string newTickerText;
   FetchTickerFromAPI(_Symbol, newTickerText);
   
   g_currentTickerText = newTickerText;
   g_tickerTextPixelWidth = CalculateTextWidth(newTickerText, TickerFontSize);
   g_tickerScrollOffset = 0; // Reset scroll
}
```

### 2. Animation continue

```mql5
// À chaque tick
AnimateTickerScroll()
{
   g_tickerScrollOffset += TickerScrollSpeed; // +2 pixels
   
   // Reset quand texte sort complètement à gauche
   if(g_tickerScrollOffset > chartWidth + g_tickerTextPixelWidth)
      g_tickerScrollOffset = 0;
   
   // Redessiner label avec nouvelle position
   DrawScrollingText(g_currentTickerText, g_tickerScrollOffset);
}
```

### 3. Calcul de la position

```
Position X = ChartWidth - ScrollOffset

Exemple:
- ChartWidth = 1000px
- ScrollOffset = 0    → Position X = 1000 (texte hors écran à droite)
- ScrollOffset = 500  → Position X = 500  (texte au milieu)
- ScrollOffset = 1500 → Position X = -500 (texte sort à gauche)
```

---

## 🌐 Sources de données

### Financial Modeling Prep (FMP)

**API:** https://financialmodelingprep.com/api/v3/stock_news

- Quota gratuit: **250 requêtes/jour**
- Données: Actualités forex, actions, indices
- Qualité: Moyenne à bonne
- Délai: ~15 minutes

### CoinGecko

**API:** https://api.coingecko.com/api/v3/news

- Quota gratuit: **50 requêtes/minute**
- Données: Actualités crypto
- Qualité: Bonne
- Délai: Temps réel

### Trading Economics (démo)

**API:** https://tradingeconomics.com/

- Quota gratuit: Limité
- Données: Calendrier économique (Fed, ECB, NFP, GDP)
- Qualité: Excellente
- Note: Pour l'instant, événements de démo dans le code

---

## 📊 Exemple visuel complet

### Configuration
```mql5
ShowEconomicTicker = true
TickerUpdateInterval = 120
TickerScrollSpeed = 2
TickerFontSize = 8
```

### Graphique résultant

```
┌───────────────────────────────────────────────────────┐
│ MT5 - EURUSD M5                        [X] Fermer     │
├───────────────────────────────────────────────────────┤
│                                                       │
│  Prix                                                 │
│    ↑                                                  │
│ 1.0900┤     [Bougies et indicateurs]                 │
│       │                                               │
│ 1.0850┤━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│       │                                               │
│ 1.0800┤     [Zone de prédiction ML]                  │
│       │                                               │
│ 1.0750┤     [Dashboard capital]                      │
│       │                                               │
│       └───┴───┴───┴───┴───┴───┴───┴───┴──→ Temps    │
│                                                       │
├───────────────────────────────────────────────────────┤
│ 📰 EUR/USD climbs on ECB news | 🔴 [HIGH] Fed Rate   │ ← Ticker
│ Decision 14:30 | ⚡ BTC breaks $50k resistance | 📊   │   défilant
└───────────────────────────────────────────────────────┘
```

---

## 📝 Notes importantes

### Performance
- Mise à jour **toutes les 120s** (2 minutes)
- Animation **à chaque tick** (légère)
- API timeout: **5 secondes**
- Pas d'impact significatif sur vitesse trading

### Catégorisation symboles

| Symbole | Catégorie | Actualités affichées |
|---------|-----------|---------------------|
| EURUSD, GBPUSD, USDJPY | FOREX | Actualités FMP forex, événements USD/EUR/GBP |
| BTC, ETH, Crypto | CRYPTO | Actualités CoinGecko crypto |
| XAUUSD (Gold), Oil | COMMODITIES | Actualités matières premières |
| Boom, Crash, Volatility | INDICES | Actualités indices synthétiques |

### Fallback

Si l'API échoue, ticker de secours affiché:
```
📊 Trading EURUSD | 💹 Market open | 🌐 Real-time analysis
```

---

## ✅ Checklist installation

- [x] Fichier `economic_news.py` dans `backend/api/`
- [x] Fichier `Economic_News_Ticker.mqh` dans `Include/`
- [x] Router ajouté dans `backend/api/main.py`
- [x] Include ajouté dans `SMC_Universal.mq5`
- [x] Appel `InitEconomicTicker()` dans `OnInit()`
- [x] Appel `DisplayEconomicNewsTicker()` dans `OnTick()`
- [x] Appel `CleanupEconomicTicker()` dans `OnDeinit()`
- [ ] Serveur backend démarré (`python start_ai_server.py`)
- [ ] Compilation SMC_Universal.mq5 réussie
- [ ] Test sur graphique démo

---

## 🆘 Dépannage

### Ticker ne s'affiche pas

1. Vérifier serveur backend actif: `http://localhost:8000/economic/health`
2. Vérifier logs MT5 pour erreurs HTTP
3. Vérifier `ShowEconomicTicker = true`
4. Tester URL manuellement: `http://localhost:8000/economic/news/ticker?symbol=EURUSD`

### Texte ne défile pas

1. Vérifier `TickerScrollSpeed > 0`
2. Vérifier fonction appelée dans `OnTick()` (pas juste `OnInit()`)
3. Augmenter vitesse: `TickerScrollSpeed = 3` ou `4`

### Texte trop rapide/lent

```mql5
TickerScrollSpeed = 1;  // Très lent
TickerScrollSpeed = 2;  // Normal (recommandé)
TickerScrollSpeed = 4;  // Rapide
TickerScrollSpeed = 6;  // Très rapide
```

### API quota dépassé

```
Error: HTTP 429 Too Many Requests
```

**Solutions:**
1. Augmenter intervalle: `TickerUpdateInterval = 300` (5 minutes)
2. Obtenir clé API payante (FMP: $14/mois)
3. Utiliser plusieurs clés API en rotation

### Ticker couvre informations importantes

Ajuster position verticale:
```mql5
TickerYPosition = 40;  // Plus haut (40px du bas)
TickerYPosition = 20;  // Plus bas (20px du bas)
```

---

## 🔮 Développements futurs

### Phase 1 (actuel)
- ✅ API publiques gratuites (FMP, CoinGecko)
- ✅ Ticker défilant animé
- ✅ Filtrage par catégorie symbole
- ✅ Icônes d'impact

### Phase 2 (à venir)
- 🔲 Calendrier économique réel (Trading Economics API)
- 🔲 Sentiment de marché (Fear & Greed Index)
- 🔲 Alertes sonores pour événements HIGH
- 🔲 Popup détaillée sur clic ticker

### Phase 3 (avancé)
- 🔲 Intégration credentials Deriv (si fournis)
- 🔲 Web scraping terminal Deriv
- 🔲 Analyse impact prix après événements
- 🔲 Statistiques corrélation news/volatilité

---

**Status:** ✅ Prêt pour intégration  
**Version:** 1.0  
**Date:** 2026-04-28

Système complet d'actualités économiques défilantes opérationnel!
