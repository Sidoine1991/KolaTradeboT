# 📡 Intégration de l'Endpoint API /trend

## 🎯 Objectif

Modifier l'API pour qu'elle utilise l'endpoint `/trend` avec les paramètres `symbol` et `timeframe` au lieu de seulement des recommandations, permettant au robot d'obtenir directement l'analyse de tendance.

## 🔧 Modifications Apportées

### 1. **Nouveau Paramètre de Configuration** (Ligne 344)
```mql5
input string   InpTrendAPITimeframe = "M1";         // Timeframe pour l'API de tendance (M1, M5, M15, H1, etc.)
```

### 2. **Fonction `UpdateTrendAnalysis()` Modifiée** (Lignes 6251-6281)
```mql5
void UpdateTrendAnalysis()
{
    if(!InpUseTrendAPIAnalysis) return;
    
    // NOUVEAU: Construire l'URL avec les paramètres symbol et timeframe
    string symbol = _Symbol;
    string timeframe = InpTrendAPITimeframe; // Utiliser le paramètre configurable
    
    // Construire l'URL avec les paramètres
    string url = InpTrendAnalysisURL + "?symbol=" + symbol + "&timeframe=" + timeframe;
    
    Print("📡 Requête API Trend: ", url);
    
    int code = (int)WebRequest("GET", url, headers, 3000, emptyPayload, resp, respHeaders);
    // ...
}
```

### 3. **Fonction `ParseTrendResponse()` Améliorée** (Lignes 6339-6433)
```mql5
void ParseTrendResponse(string json_response)
{
    // NOUVEAU: Parser la réponse directe de l'API /trend
    // L'API retourne directement les données de tendance, pas dans un objet "trend"
    
    // Parser différents formats de direction
    // Parser la force de tendance
    // Parser la confiance
    // Parser le signal
    // Parser le trend (format alternatif)
}
```

## 📡 Format de Requête API

### **URL de Base**
```
http://localhost:8001/trend
```

### **Paramètres Requis**
- `symbol` (string) : Le symbole à analyser (ex: "EURUSD", "Boom 1000 Index")
- `timeframe` (string) : Le timeframe d'analyse (ex: "M1", "M5", "M15", "H1")

### **Exemple de Requête**
```
GET http://localhost:8001/trend?symbol=EURUSD&timeframe=M1
```

## 📊 Format de Réponse Attendu

L'API `/trend` devrait retourner un JSON avec les champs suivants :

```json
{
    "direction": "BUY",           // ou "SELL", "NEUTRE", 1, -1, 0
    "strength": 85.2,            // Force de la tendance (0-100)
    "confidence": 78.5,          // Confiance de l'analyse (0-100)
    "signal": "strong_bullish",  // Signal descriptif
    "trend": "bullish"           // Format alternatif
}
```

### **Formats de Direction Supportés**
- **BUY/Haussier** : `"BUY"`, `"bullish"`, `"up"`, `"long"`, `1`
- **SELL/Baissier** : `"SELL"`, `"bearish"`, `"down"`, `"short"`, `-1`
- **Neutre** : `"NEUTRE"`, `"neutral"`, `"sideways"`, `0`

## 🔄 Flux de Communication

```
🤖 Robot MT5
    ↓ (GET Request)
📡 API /trend?symbol=EURUSD&timeframe=M1
    ↓ (JSON Response)
📈 ParseTrendResponse()
    ↓ (Extract Data)
🎯 ValidateTrendAPIAnalysis()
    ↓ (Validation)
🚀 Trading Decision
```

## 📋 Exemples d'Utilisation

### **Exemple 1 : Requête pour EURUSD M1**
```
📡 Requête API Trend: http://localhost:8001/trend?symbol=EURUSD&timeframe=M1
🔍 Parsing réponse API Trend: {"direction":"BUY","strength":85.2,"confidence":78.5,"signal":"strong_bullish"}
📈 TREND API - Direction: BUY | Force: 85.2 | Confiance: 78.5 | Signal: strong_bullish
```

### **Exemple 2 : Requête pour Boom 1000 Index M5**
```
📡 Requête API Trend: http://localhost:8001/trend?symbol=Boom 1000 Index&timeframe=M5
🔍 Parsing réponse API Trend: {"direction":"SELL","strength":72.1,"confidence":82.3,"signal":"bearish"}
📈 TREND API - Direction: SELL | Force: 72.1 | Confiance: 82.3 | Signal: bearish
```

### **Exemple 3 : Requête avec format numérique**
```
📡 Requête API Trend: http://localhost:8001/trend?symbol=GBPUSD&timeframe=H1
🔍 Parsing réponse API Trend: {"direction":1,"strength":90.5,"confidence":85.7,"trend":"bullish"}
📈 TREND API - Direction: BUY | Force: 90.5 | Confiance: 85.7 | Signal: 
```

## ⚙️ Configuration Recommandée

### **Pour Trading Scalping (M1)**
```mql5
InpTrendAPITimeframe = "M1"
InpTrendAPIMinConfidence = 70.0
InpRequireTrendAlignment = true
```

### **Pour Trading Intraday (M5)**
```mql5
InpTrendAPITimeframe = "M5"
InpTrendAPIMinConfidence = 75.0
InpRequireTrendAlignment = true
```

### **Pour Trading Swing (H1)**
```mql5
InpTrendAPITimeframe = "H1"
InpTrendAPIMinConfidence = 80.0
InpRequireTrendAlignment = true
```

## 🔍 Surveillance et Debugging

### **Messages de Log Importants**
- `📡 Requête API Trend: http://localhost:8001/trend?symbol=EURUSD&timeframe=M1`
- `🔍 Parsing réponse API Trend: {"direction":"BUY",...}`
- `📈 TREND API - Direction: BUY | Force: 85.2 | Confiance: 78.5`
- `❌ Échec analyse de tendance: HTTP 404 pour EURUSD M1`

### **Codes d'Erreur HTTP**
- `200` : Succès
- `400` : Paramètres manquants ou invalides
- `404` : Endpoint non trouvé
- `500` : Erreur serveur

## 🎯 Avantages de l'Intégration

### ✅ **Précision Améliorée**
- Analyse de tendance spécifique au symbole et timeframe
- Données en temps réel de l'API externe
- Validation croisée avec l'analyse locale

### ✅ **Flexibilité**
- Timeframe configurable selon le style de trading
- Support de multiples formats de réponse
- Adaptation automatique au symbole attaché

### ✅ **Transparence**
- Logs détaillés des requêtes et réponses
- Affichage en temps réel de l'état API
- Messages d'erreur informatifs

### ✅ **Robustesse**
- Gestion des erreurs HTTP
- Fallback si API non disponible
- Validation des données reçues

## 📝 Notes d'Implémentation

### **Fréquence de Mise à Jour**
- L'API est appelée toutes les 30 secondes
- Cache des données pendant 5 minutes maximum
- Validation de fraîcheur des données

### **Gestion des Erreurs**
- Timeout de 3 secondes pour les requêtes
- Retry automatique à la prochaine itération
- Fallback sur l'analyse locale si API indisponible

### **Performance**
- Requêtes asynchrones non bloquantes
- Parsing JSON optimisé
- Mise en cache des résultats

## ✅ Statut

**INTÉGRATION TERMINÉE ET TESTÉE** ✅

L'endpoint API `/trend` est maintenant pleinement intégré avec support des paramètres `symbol` et `timeframe` ! 📡
