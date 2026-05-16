# 🧠 OLLAMA INTEGRATION - TradBOT Enhanced

## 📋 Vue d'ensemble

Intégration complète d'un modèle LLM local (Ollama) pour analyse approfondie des indicateurs techniques du TradBOT.

### Fonctionnalités
- **Analyse approfondie** : Envoi de tous les indicateurs techniques à un LLM local
- **Affichage graphique** : Résultats affichés en temps réel sur le graphique MT5
- **Notifications** : Résumés toutes les 5 minutes par symbole
- **Niveaux clés** : Support/Résistance automatiquement identifiés et dessinés

## 🏗️ Architecture

### 1. ai_server.py - Endpoint `/analyze/ollama`
```python
# Modèles Pydantic
class OllamaAnalysisRequest(BaseModel)
class OllamaAnalysisResponse(BaseModel)

# Fonctions principales
- _call_ollama_local() → Appel HTTP à Ollama
- _build_ollama_prompt() → Prompt structuré avec indicateurs
- _parse_ollama_json() → Parsing robuste avec fallback
```

### 2. SMC_Universal_Enhanced.mq5 - Pont Ollama
```mql5
// Structures
struct OllamaAnalysis
struct AISignal

// Variables globales
OllamaAnalysis g_lastOllamaAnalysis
datetime g_lastOllamaUpdateTime
string g_ollamaLastSummary

// Fonctions principales
- UpdateOllamaAnalysis() → Envoi indicateurs toutes les 5 min
- DisplayOllamaAnalysis() → Affichage graphique
- NotifyOllamaAnalysis() → Notifications push
```

## 📊 Indicateurs envoyés à Ollama

### Données de marché
- Symbol, Timeframe, Bid/Ask, ATR
- RSI(14), MACD Histogramme, Ichimoku Bias

### EMAs multi-timeframes
- M1: EMA 9/21
- M5: EMA 9/21  
- H1: EMA 9/21

### Entry points GOM KOLA
- M1/M5/M15/H1 BUY/SELL entries
- Volume spike, accélération prix

## 🎨 Affichage graphique

### Labels (coin supérieur droit)
1. **OLLAMA_SUMMARY** : Sentiment + Recommandation + Confiance
2. **OLLAMA_REASON** : Raison de la décision (tronquée à 80 chars)
3. **OLLAMA_LEVELS** : Support/Résistance/RR
4. **OLLAMA_LAT** : Latence en ms

### Lignes horizontales
- **OLLAMA_SUPPORT** : Ligne verte pointillée
- **OLLAMA_RESISTANCE** : Ligne rouge pointillée

### Couleurs par sentiment
- 🟢 BULLISH : Vert lime
- 🔴 BEARISH : Rouge cramoisi
- ⚪ NEUTRAL : Or

## 🔔 Système de notifications

### Fréquence
- **Toutes les 5 minutes** par symbole
- **Anti-doublon** : Pas de notification si summary identique

### Format
```
🧠 OLLAMA EURUSD M5
BUY (conf 75%)
Tendance haussière confirmée sur M1/M5 avec RSI surachat
```

## ⚙️ Configuration

### Variables d'environnement (ai_server.py)
```bash
OLLAMA_URL=http://localhost:11434/api/generate
OLLAMA_MODEL=qwen3.5:4b
```

### Variables MQL5
```mql5
int g_ollamaUpdateInterval = 300; // 5 minutes
bool UseAIServer = true;
```

## 🚀 Installation

### 1. Installer Ollama
```bash
# Linux/macOS
curl -fsSL https://ollama.ai/install.sh | sh

# Windows
# Télécharger depuis https://ollama.ai/download
```

### 2. Télécharger un modèle
```bash
ollama pull qwen3.5:4b
# ou
ollama pull llama3
# ou
ollama pull gemma3
```

**Note** : Le modèle qwen3.5:4b doit être dans le dossier Ollama sur le disque D (ex: `D:\Ollama\models\`)

### 3. Démarrer Ollama
```bash
ollama serve
# Ollama écoute sur http://localhost:11434
```

### 4. Démarrer ai_server.py
```bash
python ai_server.py
# Endpoint disponible : http://localhost:8000/analyze/ollama
```

### 5. Compiler et lancer SMC_Universal_Enhanced.mq5
- Activer `UseAIServer = true`
- Les logs montreront "🧠 OLLAMA: Envoi analyse..."

## 🔧 Dépannage

### Logs importants
```
🧠 OLLAMA: Envoi analyse pour EURUSD → http://localhost:8000/analyze/ollama
🧠 OLLAMA: Réponse reçue (1500 chars)
✅ OLLAMA: Parse OK - Sentiment=BULLISH Reco=BUY Conf=75.0% Lat=1200ms
🧠 OLLAMA NOTIF: 🟢 OLLAMA EURUSD M5 | BUY (conf 75%) | Tendance haussière...
```

### Erreurs communes
- **"Ollama indisponible"** : Vérifier que Ollama tourne sur localhost:11434
- **"HTTP 404"** : Vérifier que ai_server.py inclut bien le nouvel endpoint
- **"Parsing échoué"** : Le modèle LLM ne suit pas le format JSON attendu

### Tests manuels
```bash
# Tester Ollama directement
curl http://localhost:11434/api/generate \
  -d '{"model":"gemma3","prompt":"Analyse EURUSD","stream":false}'

# Tester endpoint ai_server
curl -X POST http://localhost:8000/analyze/ollama \
  -H "Content-Type: application/json" \
  -d '{"symbol":"EURUSD","bid":1.1234,"ask":1.1236,"rsi":55.0}'
```

## 🎯 Cas d'usage

### Trading basé sur Ollama
1. **Surveiller les notifications** : Recevoir des analyses toutes les 5 minutes
2. **Vérifier les niveaux** : Support/Résistance automatiquement dessinés
3. **Confiance élevée** : Prioriser les signaux avec confiance > 70%
4. **Sentiment aligné** : Confirmer avec l'IA décisionnelle existante

### Complémentarité
- **IA décisionnelle** : Signaux rapides toutes les 30 secondes
- **Ollama analyse** : Contexte profond toutes les 5 minutes
- **Script verdict** : Validation finale pour exécution

## 📈 Performance

### Latence typique
- **Appel Ollama** : 500-2000ms selon modèle
- **Parsing JSON** : < 50ms
- **Affichage graphique** : < 10ms

### Ressources
- **CPU** : Modèle Gemma3 ~ 2-4 cores
- **RAM** : 2-8GB selon modèle
- **Réseau** : Local uniquement (localhost)

---

**Version** : 1.0  
**Date** : 2026-05-08  
**Auteur** : TradBOT Enhanced Team
