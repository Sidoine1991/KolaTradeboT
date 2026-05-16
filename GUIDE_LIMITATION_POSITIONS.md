# 🔢 GUIDE DE LIMITATION DES POSITIONS SIMULTANÉES

## Vue d'ensemble

Le système limite automatiquement le nombre de positions ouvertes simultanément pour éviter la sur-exposition et améliorer la gestion des risques.

---

## 🎯 Règles par Défaut

### Par Défaut : 2 Positions Maximum
```
✅ Position 1 : Crash 300 Index (ouverte)
✅ Position 2 : Boom 1000 Index (ouverte)
❌ Position 3 : EUR/USD (REFUSÉE - limite atteinte)
```

### Mode Strict : 1 Seule Position
```
✅ Position 1 : Crash 300 Index (ouverte)
❌ Position 2 : Boom 1000 Index (REFUSÉE - limite atteinte)
```

---

## ⚙️ Configuration

### Méthode 1 : Variable d'Environnement (Recommandé)

**Fichier `.env` ou `.env.supabase` :**
```bash
# Limite de positions simultanées
MT5_MAX_POSITIONS=2

# Pour mode strict (1 seule position)
# MT5_MAX_POSITIONS=1

# Perte maximale par trade
MT5_MAX_LOSS_PER_TRADE=3.0
```

### Méthode 2 : Paramètre de Fonction

**Dans le code Python :**
```python
from backend.mt5_order_utils import place_order_mt5

# Avec limite de 2 positions
place_order_mt5(
    symbol="Crash 300 Index",
    order_type="BUY",
    lot=0.4,
    max_positions=2  # Limite à 2 positions
)

# Avec mode strict (1 seule position)
place_order_mt5(
    symbol="Boom 1000 Index",
    order_type="SELL",
    lot=0.3,
    max_positions=1  # Une seule position autorisée
)
```

---

## 📊 Endpoints API

### Vérifier le Statut Global

```bash
curl http://localhost:8000/monitor/status
```

**Réponse :**
```json
{
  "protection_active": true,
  "max_loss_per_trade": 3.0,
  "max_positions_simultaneous": 2,
  "mt5_connected": true,
  "open_positions_count": 1,
  "can_open_new_position": true,
  "monitoring_interval": "1 second",
  "api_available": true
}
```

### Vérifier si Nouvelle Position Autorisée

```bash
# Avec limite par défaut (2)
curl http://localhost:8000/monitor/positions

# Avec limite personnalisée (1 seule position)
curl "http://localhost:8000/monitor/positions?max_positions=1"
```

**Réponse (OK) :**
```json
{
  "current_positions": 1,
  "max_positions": 2,
  "can_open_new": true,
  "message": "OK : 1/2 positions ouvertes",
  "remaining_slots": 1
}
```

**Réponse (LIMITE ATTEINTE) :**
```json
{
  "current_positions": 2,
  "max_positions": 2,
  "can_open_new": false,
  "message": "Limite de positions atteinte : 2/2 positions ouvertes",
  "remaining_slots": 0
}
```

---

## 🚀 Cas d'Usage

### Cas 1 : Trading Conservateur (1 seule position)

**Configuration :**
```bash
# .env
MT5_MAX_POSITIONS=1
MT5_MAX_LOSS_PER_TRADE=3.0
```

**Avantages :**
- ✅ Exposition minimale
- ✅ Gestion simplifiée
- ✅ Risque concentré sur 1 trade
- ✅ Idéal pour débutants

**Exemple :**
```
14:30:00 - Position Crash 300 ouverte (0.4 lot)
14:35:00 - Tentative d'ouvrir Boom 1000
           ❌ REFUSÉ : Limite de positions atteinte (1/1)
14:40:00 - Position Crash 300 fermée (+2.50$)
14:42:00 - Position Boom 1000 ouverte (0.3 lot)
           ✅ AUTORISÉ : 1/1 positions ouvertes
```

### Cas 2 : Trading Équilibré (2 positions max)

**Configuration :**
```bash
# .env
MT5_MAX_POSITIONS=2
MT5_MAX_LOSS_PER_TRADE=3.0
```

**Avantages :**
- ✅ Diversification possible
- ✅ 2 opportunités simultanées
- ✅ Risque total max : 6$ (2 × 3$)
- ✅ Équilibre risque/opportunité

**Exemple :**
```
14:30:00 - Position Crash 300 ouverte (0.4 lot)
14:35:00 - Position Boom 1000 ouverte (0.3 lot)
           ✅ AUTORISÉ : 2/2 positions ouvertes
14:40:00 - Tentative d'ouvrir EUR/USD
           ❌ REFUSÉ : Limite de positions atteinte (2/2)
14:45:00 - Position Crash 300 fermée (-3.00$ - stop loss)
14:50:00 - Position EUR/USD ouverte (0.2 lot)
           ✅ AUTORISÉ : 2/2 positions ouvertes
```

### Cas 3 : Trading Agressif (3+ positions)

**Configuration :**
```bash
# .env
MT5_MAX_POSITIONS=3
MT5_MAX_LOSS_PER_TRADE=3.0
```

**Avantages :**
- ✅ Maximum d'opportunités
- ✅ Diversification étendue
- ⚠️ Risque total : 9$ (3 × 3$)
- ⚠️ Gestion plus complexe

---

## 🔒 Mécanisme de Protection

### Vérifications Avant Ouverture

```python
# 1. Vérifier la connexion MT5
if not is_connected():
    return False, "MT5 n'est pas connecté"

# 2. Vérifier la limite de positions
all_positions = mt5.positions_get()
if len(all_positions) >= max_positions_allowed:
    return False, f"Limite atteinte : {len(all_positions)}/{max_positions_allowed}"

# 3. Vérifier doublon sur le symbole
existing_on_symbol = mt5.positions_get(symbol=symbol)
if len(existing_on_symbol) > 0:
    return False, f"Position déjà ouverte sur {symbol}"

# 4. Ouvrir la position
# ...
```

### Messages d'Erreur

**Limite de positions atteinte :**
```
❌ Limite de positions atteinte : 2/2 positions ouvertes. 
   Fermez une position avant d'en ouvrir une nouvelle.
```

**Doublon sur symbole :**
```
❌ Ordre refusé: une position est déjà ouverte sur Crash 300 Index.
```

---

## 📊 Monitoring en Temps Réel

Le script `continuous_loss_monitor.py` affiche le nombre de positions :

```
✅ [14:30:00] Positions surveillées : 2/2
   • Crash 300 Index : -1.25$ (OK)
   • Boom 1000 Index : +0.80$ (OK)

⚠️  [14:32:15] ALERTE: Position fermée automatiquement
   • Symbole: Crash 300 Index
   • Perte: -3.05$
   • Positions restantes: 1/2
```

---

## 🧪 Tests

### Test 1 : Vérifier la Limite

```python
from backend.mt5_connector import can_open_new_position, get_open_positions_count

# Avec limite de 2
can_open, message = can_open_new_position(max_positions=2)
print(f"Peut ouvrir : {can_open}")
print(f"Message : {message}")

# Nombre actuel
count = get_open_positions_count()
print(f"Positions ouvertes : {count}")
```

### Test 2 : Tester l'API

```bash
# Statut global
curl http://localhost:8000/monitor/status

# Vérifier limite
curl "http://localhost:8000/monitor/positions?max_positions=1"
```

### Test 3 : Simuler Ouverture

```python
from backend.mt5_order_utils import place_order_mt5

# Tenter d'ouvrir 3 positions avec limite de 2
for i in range(3):
    success, msg = place_order_mt5(
        symbol=f"TEST_SYMBOL_{i}",
        order_type="BUY",
        lot=0.1,
        max_positions=2
    )
    print(f"Position {i+1}: {success} - {msg}")
```

**Résultat attendu :**
```
Position 1: True - Ordre exécuté
Position 2: True - Ordre exécuté
Position 3: False - Limite de positions atteinte : 2/2
```

---

## 📈 Exemples de Configuration

### Configuration Débutant
```bash
MT5_MAX_POSITIONS=1          # 1 seule position
MT5_MAX_LOSS_PER_TRADE=2.0   # 2$ max par trade
```
**Risque total max : 2$**

### Configuration Intermédiaire
```bash
MT5_MAX_POSITIONS=2          # 2 positions max
MT5_MAX_LOSS_PER_TRADE=3.0   # 3$ max par trade
```
**Risque total max : 6$**

### Configuration Avancée
```bash
MT5_MAX_POSITIONS=3          # 3 positions max
MT5_MAX_LOSS_PER_TRADE=5.0   # 5$ max par trade
```
**Risque total max : 15$**

---

## 🔄 Intégration avec Robot MQL5

### Dans votre EA MQL5

```cpp
// Vérifier avant d'ouvrir une position
string url = "http://localhost:8000/monitor/positions?max_positions=2";
string headers = "";
char result[];
string result_headers;

int res = WebRequest(
    "GET",
    url,
    headers,
    5000,
    result,
    result_headers
);

if (res == 200) {
    string json = CharArrayToString(result);
    // Parser JSON pour can_open_new
    // Si false, ne pas ouvrir la position
}
```

---

## ⚠️ Points d'Attention

### Limitations
- ⚠️ La vérification se fait à l'ouverture uniquement
- ⚠️ Les positions manuelles comptent aussi
- ⚠️ Les ordres en attente ne comptent pas (seulement positions ouvertes)

### Recommandations
- ✅ Commencer avec `MT5_MAX_POSITIONS=1` pour débuter
- ✅ Augmenter progressivement selon l'expérience
- ✅ Surveiller le risque total = max_positions × max_loss
- ✅ Utiliser le monitoring continu pour suivi en temps réel

---

## 🎯 Résumé Rapide

**Limite par défaut : 2 positions**
```bash
# .env
MT5_MAX_POSITIONS=2
```

**Mode strict (1 seule position) :**
```bash
# .env
MT5_MAX_POSITIONS=1
```

**Vérifier le statut :**
```bash
curl http://localhost:8000/monitor/positions
```

**Protection active :**
- ✅ Limite automatique de positions
- ✅ Perte max 3$ par position
- ✅ Risque total contrôlé
- ✅ Messages d'erreur clairs

---

**Version :** 1.0  
**Dernière mise à jour :** 2026-04-28  
**Status :** ✅ Opérationnel
