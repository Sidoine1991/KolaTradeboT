# 🔍 DIAGNOSTIC LOGS MT5 - Problèmes Identifiés

**Date** : 2026-05-15  
**Analyse** : Logs terminal MT5  
**Statut** : ⚠️ PROBLÈMES DÉTECTÉS

---

## 🔴 PROBLÈMES IDENTIFIÉS

### 1️⃣ **SERVEUR IA NON ACCESSIBLE** (Critique)

```
❌ Résultat primaire: HTTP 1003
❌ PropiceTop - Erreur HTTP 404 (err 5203)
```

**Diagnostic** :
- Code **HTTP 1003** = Erreur de connexion (serveur non joignable)
- Serveur local `http://127.0.0.1:8000` ne répond pas
- Fallback Render donne erreur 404 (endpoint manquant)

**Impact** :
- ❌ Robot ne peut pas obtenir décisions IA
- ❌ Aucun trade possible
- ❌ Scanner propice ne fonctionne pas

---

### 2️⃣ **CONFIANCE IA TROP STRICTE** (Bloquant)

```
❌ TRADE BLOQUÉ - Confiance IA insuffisante | 57.2% < 65.0%
❌ TRADE BLOQUÉ - Pas de décision IA forte (conf: 62.0% < 85.0%)
❌ TRADE BLOQUÉ - Pas de décision IA forte (conf: 55.8% < 85.0%)
```

**Diagnostic** :
- Seuils trop stricts après optimisations (85% confiance min)
- Opportunités réelles rejetées (55-62% sont acceptables)
- Aucun trade ne passe les filtres

**Impact** :
- ❌ 0 trade ouvert malgré opportunités
- ❌ Robot trop conservateur
- ❌ Capital non utilisé

---

### 3️⃣ **ENDPOINT PROPICE MANQUANT** (Non-critique)

```
⚠️ PropiceTop - Réponse vide ou invalide
❌ PropiceTop - Erreur HTTP 404
```

**Diagnostic** :
- Endpoint `/symbols/propice/top` n'existe pas dans ai_server.py
- Feature optionnelle (classement symboles propices)
- Peut fonctionner sans cet endpoint

**Impact** :
- ⚠️ Pas de classement symboles
- ✅ Trading reste possible si IA connectée

---

### 4️⃣ **IA BLOQUE DIRECTIONS** (Normal)

```
🚫 SMC_OTE BLOQUÉ - L'IA n'autorise pas la direction BUY sur USDJPY
🚫 SMC_OTE BLOQUÉ - L'IA n'autorise pas la direction SELL sur GBPUSD
```

**Diagnostic** :
- IA détecte conditions défavorables
- Protection contre trades contre-tendance
- **Comportement normal et souhaité**

**Impact** :
- ✅ Protection capital fonctionnelle
- ✅ Évite trades perdants

---

### 5️⃣ **AUCUNE POSITION OUVERTE** (Conséquence)

```
Positions totales: 0
```

**Diagnostic** :
- Résultat des problèmes 1 et 2
- Serveur IA non accessible + seuils trop stricts
- Robot en attente mais ne peut pas trader

**Impact** :
- ❌ Capital 20$ non utilisé
- ❌ Aucun profit généré

---

## ✅ SOLUTIONS

### SOLUTION 1 : Démarrer Serveur IA (Priorité 1) 🔴

**Problème** : HTTP 1003 (serveur non accessible)

**Actions** :

#### A. Vérifier si ai_server.py tourne

```bash
# Ouvrir PowerShell / CMD
cd D:\Dev\TradBOT

# Vérifier si déjà lancé
netstat -ano | findstr :8000
```

**Si aucun résultat** → Serveur pas lancé

#### B. Démarrer ai_server.py

```bash
python ai_server.py
```

**Sortie attendue** :
```
✅ INFO: Started server process [XXXX]
✅ INFO: Uvicorn running on http://127.0.0.1:8000
```

#### C. Tester connexion

Ouvrir navigateur : http://127.0.0.1:8000/health

**Réponse attendue** :
```json
{
  "status": "healthy",
  "timestamp": "2026-05-15T...",
  "version": "2.1.0"
}
```

**Si erreur** → Lire logs ai_server.py et corriger

---

### SOLUTION 2 : Ajuster Seuils Confiance (Priorité 2) 🟡

**Problème** : Confiance 85% trop stricte (0 trade)

**Recommandation** : Réduire temporairement à 75% pour démo test

#### Option A : Modifier ai_server.py (Recommandé)

```python
# Fichier: ai_server.py ligne 206
MIN_CONFIDENCE_THRESHOLD = 0.75  # Réduit de 0.72 à 0.75 pour test

# Ligne ~450-460 (plancher confiance)
confidence = max(0.75, raw_confidence)  # Était 0.75, garder
```

**Redémarrer** ai_server.py après modification

#### Option B : Modifier SMC_Universal.mq5 (Plus rapide)

```mql5
// Fichier: SMC_Universal.mq5 ligne 8647
input double MinAIConfidencePercent = 75.0;  // Réduit de 85% à 75% pour test
input double MinAIConfidence = 0.75;          // Aligné
```

**Recompiler** SMC_Universal.mq5 après modification

#### Option C : Via Inputs MT5 (Sans recompilation)

```
1. Retirer EA du graphique
2. Réattacher EA
3. Dans fenêtre Inputs :
   - MinAIConfidencePercent = 75.0  (au lieu de 85)
   - MinSetupScoreEntry = 70.0      (au lieu de 80)
4. OK
```

**Résultat attendu** :
- ✅ Opportunités 55-75% acceptées
- ✅ Trades commencent à s'ouvrir
- ✅ Win rate observé réel

**Après 2-3 jours** :
- Mesurer win rate réel
- Si ≥ 70% → Garder 75%
- Si < 65% → Remonter à 80%

---

### SOLUTION 3 : Ajouter Endpoint Propice (Optionnel) 📋

**Problème** : Endpoint `/symbols/propice/top` manquant

**Impact** : Mineur (feature optionnelle)

**Solution si désiré** :

Ajouter dans `ai_server.py` :

```python
@app.get("/symbols/propice/top")
async def get_propice_top_symbols(
    timeframe: str = Query("M1"),
    lookback_days: int = Query(14),
    n: int = Query(5)
):
    """Retourne les N symboles les plus propices au trading"""
    try:
        # Placeholder simple
        return {
            "symbols": [
                {"symbol": "Boom 1000 Index", "score": 0.85, "rank": 1},
                {"symbol": "Crash 1000 Index", "score": 0.82, "rank": 2},
                {"symbol": "EURUSD", "score": 0.78, "rank": 3},
                {"symbol": "XAUUSD", "score": 0.75, "rank": 4}
            ],
            "timeframe": timeframe,
            "lookback_days": lookback_days
        }
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": str(e)}
        )
```

**Redémarrer** ai_server.py

**Note** : Pas urgent, robot fonctionne sans

---

## 📊 PLAN D'ACTION PRIORITAIRE

### ÉTAPE 1 : Démarrer IA (5 min) 🔴

```
1. Ouvrir terminal
2. cd D:\Dev\TradBOT
3. python ai_server.py
4. Vérifier : http://127.0.0.1:8000/health
✅ Résout HTTP 1003
```

### ÉTAPE 2 : Réduire Seuils (2 min) 🟡

```
Option rapide (Sans recompiler) :
1. Retirer EA du graphique
2. Réattacher EA
3. Inputs : MinAIConfidencePercent = 75.0
4. OK
✅ Résout "Confiance insuffisante"
```

### ÉTAPE 3 : Relancer MT5 (1 min)

```
1. Fermer MT5
2. Relancer MT5
3. Attacher EA
4. Vérifier logs : pas d'erreur HTTP 1003
✅ Robot prêt à trader
```

### ÉTAPE 4 : Observer (30 min)

```
✅ Logs : "IA connected" (pas HTTP 1003)
✅ Trades : opportunités acceptées (conf 55-75%)
✅ Positions : 1-2 positions ouvertes max
✅ Dashboard : affichage correct
```

---

## 🔧 VÉRIFICATIONS SUPPLÉMENTAIRES

### Si ai_server.py ne démarre pas

**Erreur : `ModuleNotFoundError`**

```bash
# Solution : Réinstaller dépendances
pip install fastapi uvicorn pandas numpy requests --upgrade
```

**Erreur : `Port 8000 already in use`**

```bash
# Solution : Tuer processus existant
# Windows
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# Ou changer port dans ai_server.py
# Ligne ~dernière : port=8000 → port=8001
```

### Si MT5 ne voit toujours pas l'IA

**Vérifier WebRequest autorisés** :

```
MT5 → Outils → Options → Expert Advisors
URLs autorisées :
✅ http://127.0.0.1:8000
✅ https://kolatradebot-7ofl.onrender.com
```

**Vérifier Firewall Windows** :

```
Panneau de configuration → Pare-feu Windows
→ Applications autorisées
→ Ajouter Python (python.exe)
```

---

## ✅ RÉSUMÉ RAPIDE

```
╔═══════════════════════════════════════════════════════════╗
║  PROBLÈME PRINCIPAL : IA NON ACCESSIBLE                   ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  CAUSE :                                                  ║
║  • ai_server.py pas lancé                                 ║
║  • Port 8000 bloqué                                       ║
║  • WebRequest non autorisé MT5                            ║
║                                                           ║
║  SOLUTION :                                               ║
║  1️⃣  Lancer : python ai_server.py                        ║
║  2️⃣  Tester : http://127.0.0.1:8000/health               ║
║  3️⃣  Relancer MT5                                         ║
║                                                           ║
╠═══════════════════════════════════════════════════════════╣
║  PROBLÈME SECONDAIRE : SEUILS TROP STRICTS                ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  CAUSE :                                                  ║
║  • Confiance 85% trop élevée                              ║
║  • Aucune opportunité ne passe                            ║
║                                                           ║
║  SOLUTION :                                               ║
║  • Réduire à 75% pour test (inputs MT5)                   ║
║  • Observer win rate réel                                 ║
║  • Ajuster selon résultats                                ║
║                                                           ║
╠═══════════════════════════════════════════════════════════╣
║  RÉSULTAT ATTENDU APRÈS CORRECTIONS                       ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  ✅ Logs : "IA connected" (HTTP 200)                      ║
║  ✅ Trades acceptés (conf 55-75%)                         ║
║  ✅ Positions ouvertes (1-2 max)                          ║
║  ✅ Robot actif et rentable                               ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

---

**Version** : 1.0 Diagnostic  
**Date** : 2026-05-15  
**Statut** : ✅ SOLUTIONS FOURNIES
