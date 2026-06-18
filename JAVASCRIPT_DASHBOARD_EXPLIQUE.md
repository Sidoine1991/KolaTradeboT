# 📖 JavaScript du Dashboard TradBOT — Explication Complète

## 📍 Où est le JavaScript ?

**Le JavaScript n'existe pas en fichier séparé** — il est **entièrement intégré dans le HTML** :

```
D:\Dev\TradBOT\dashboard\trade_journal.html
├─ Lignes 1-170: CSS (styling)
├─ Lignes 172-242: Structure HTML
└─ Lignes 243-610: JavaScript (inline)
```

---

## 🔍 Fonction Principale: `renderRecommendations()`

### **Code (Lignes 528-560):**

```javascript
async function renderRecommendations() {
  // 1. Récupère la catégorie sélectionnée
  const cat = document.getElementById('fCategory').value;
  
  // 2. Construit l'URL API
  const url = cat 
    ? `${API}/api/recommendations?category=${encodeURIComponent(cat)}` 
    : `${API}/api/recommendations`;
  
  // 3. Appel API pour charger le Top 3
  const data = await fetch(url).then(r => r.json());
  
  // 4. Référence le conteneur HTML
  const grid = document.getElementById('recoGrid');
  
  // 5. Récupère les symboles
  const items = data.top_symbols || [];
  
  // 6. Affiche message si aucune donnée
  if (!items.length) {
    grid.innerHTML = `<div class="empty">Pas assez de trades (min ${data.min_trades || 8} par symbole)...</div>`;
    return;
  }
  
  // 7. Génère les cartes HTML pour chaque Top 3
  grid.innerHTML = items.map((s, i) => `
    <div class="reco-card ${i === 0 ? 'rank1' : ''}">
      <span class="reco-rank">#${i + 1} · Score ${s.score}</span>
      <div class="reco-symbol">${s.symbol}</div>
      <div class="reco-cat">${s.category}</div>
      <div class="reco-stats">
        <span>Win ${s.win_rate}%</span>
        <span class="${s.net_pnl >= 0 ? 'pos' : 'neg'}">PnL ${s.net_pnl >= 0 ? '+' : ''}${s.net_pnl}$</span>
        <span>PF ${s.profit_factor}</span>
        <span>${s.trades} trades</span>
      </div>
      <div class="reco-hours">
        <strong>Heures propices UTC:</strong>
        ${(s.best_hours || []).map(h => `${h.label} (${h.win_rate}% · ${h.pnl >= 0 ? '+' : ''}${h.pnl}$)`).join(' · ') || '—'}
      </div>
      <div class="reco-hours">
        <strong>Entrée optimale:</strong> ${s.best_direction} (${s.direction_win_rate}% win)
        · durée moy. ${s.avg_duration_min} min
      </div>
      <div class="reco-tip">${s.entry_tip}</div>
    </div>
  `).join('');
}
```

---

## 🔗 Flux de Données

```
┌─────────────────────────┐
│   renderRecommendations()
└──────────┬──────────────┘
           │
           ├─→ Récupère catégorie du filtre
           │
           ├─→ Construit URL:
           │   http://127.0.0.1:8765/api/recommendations
           │
           ├─→ fetch(url) → API Python
           │
           ├─→ Serveur retourne JSON:
           │   {
           │     "top_symbols": [
           │       {
           │         "symbol": "Crash 1000 Index",
           │         "score": 70.4,
           │         "win_rate": 57.4,
           │         ...
           │       }
           │     ]
           │   }
           │
           ├─→ Génère HTML pour chaque symbole
           │
           └─→ Insère dans #recoGrid
```

---

## 📊 Données Affichées

Pour **chaque symbole du Top 3**, le code affiche:

| Donnée | Ligne | Code |
|--------|-------|------|
| **Rang** | 540 | `#${i + 1} · Score ${s.score}` |
| **Symbole** | 541 | `${s.symbol}` |
| **Catégorie** | 542 | `${s.category}` |
| **Win Rate** | 544 | `Win ${s.win_rate}%` |
| **PnL** | 545 | `PnL ${s.net_pnl}$` |
| **Profit Factor** | 546 | `PF ${s.profit_factor}` |
| **Trades** | 547 | `${s.trades} trades` |
| **Heures UTC** | 551 | Boucle sur `best_hours[]` |
| **Direction** | 554 | `${s.best_direction}` |
| **Durée moyenne** | 555 | `${s.avg_duration_min} min` |
| **Stratégie** | 557 | `${s.entry_tip}` |

---

## 🎨 Styling CSS

### **Classes appliquées:**

```css
.reco-card {
  /* Contenant principal pour chaque symbole */
  background: linear-gradient(145deg, #1e2a3d 0%, #1a2332 100%);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 1rem 1.1rem;
}

.reco-card.rank1 {
  /* Spécial pour le #1 (plus haute priorité) */
  border-color: var(--amber);  /* Couleur ambre (dorée)*/
}

.reco-rank {
  /* Badge "#1 · Score 70.4" */
  position: absolute;
  top: 0.75rem;
  right: 0.75rem;
  font-size: 0.7rem;
  color: var(--amber);
  background: rgba(245, 158, 11, 0.15);
}

.reco-symbol {
  /* Nom du symbole en gros */
  font-size: 1.1rem;
  font-weight: 700;
}

.reco-stats {
  /* Ligne avec Win%, PnL, PF, Trades */
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 1rem;
  font-size: 0.82rem;
}

.reco-stats span.pos {
  /* Couleur verte pour PnL positif */
  color: var(--green);
}

.reco-stats span.neg {
  /* Couleur rouge pour PnL négatif */
  color: var(--red);
}
```

---

## 🔄 Fonctions Connexes

### **1. Fonction `refresh()` (Ligne 562)**

```javascript
async function refresh() {
  try {
    // Charge status + metrics + recommendations
    const [status, metrics] = await Promise.all([
      fetch(`${API}/api/status`).then(r => r.json()),
      fetchJSON('/api/metrics')
    ]);
    
    // Mise à jour UI
    renderKPIs(metrics);
    renderCharts(metrics);
    renderTables(metrics);
    await renderTrades();
    await loadCatalog();
    await renderRecommendations();  // ← Appelle le Top 3
  } catch (e) {
    // Gestion erreur
  }
}
```

### **2. Fonction `populateSymbolFilter()` (Ligne 506)**

```javascript
async function populateSymbolFilter() {
  // Peuple le filtre symboles basé sur catégorie
  // Utilisé avec le filtre catégorie
}
```

---

## 🌐 Variables Globales

```javascript
const API = 'http://127.0.0.1:8765';  // Endpoint serveur

async function fetchJSON(path) {
  // Helper pour faire les requêtes fetch
  const r = await fetch(API + path);
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return r.json();
}
```

---

## 📋 Points Clés

| Point | Explication |
|-------|-------------|
| **Asynchrone** | Utilise `async/await` pour charger les données sans bloquer l'UI |
| **Template literals** | Utilise backticks `` ` `` pour construire le HTML dynamiquement |
| **Array.map()** | Itère sur les symboles pour générer les cartes |
| **Conditional styling** | `.rank1` appliqué seulement au #1 (i === 0) |
| **Coleurs dynamiques** | Vert pour PnL positif, rouge pour négatif |
| **Fallback** | `||` utilisé pour fournir des valeurs par défaut |

---

## 🚀 Comment Ça Marche

### **Étape 1: Page charge**
```javascript
// window.onload ou DOMContentLoaded
await refresh();  // Appelle renderRecommendations()
```

### **Étape 2: Utilisateur change la catégorie**
```javascript
document.getElementById('fCategory').addEventListener('change', () => {
  refresh();
  renderRecommendations();  // Recharge le Top 3 avec la catégorie
});
```

### **Étape 3: API retourne les données**
```json
{
  "top_symbols": [
    {
      "symbol": "Crash 1000 Index",
      "category": "BOOM_CRASH",
      "score": 70.4,
      "trades": 61,
      "win_rate": 57.4,
      "net_pnl": 7.59,
      "profit_factor": 1.24,
      "avg_duration_min": 12.5,
      "best_direction": "SELL",
      "direction_win_rate": 57.4,
      "best_hours": [
        {"hour_utc": 23, "label": "23h-24h UTC", "win_rate": 100.0, "pnl": 9.95},
        {"hour_utc": 18, "label": "18h-19h UTC", "win_rate": 100.0, "pnl": 2.58}
      ],
      "entry_tip": "Boom: BUY only | Crash: SELL only..."
    }
  ],
  "eligible_count": 12,
  "min_trades": 8
}
```

### **Étape 4: HTML généré et affiché**
```html
<div class="reco-card rank1">
  <span class="reco-rank">#1 · Score 70.4</span>
  <div class="reco-symbol">Crash 1000 Index</div>
  <div class="reco-cat">BOOM_CRASH</div>
  <div class="reco-stats">
    <span>Win 57.4%</span>
    <span class="pos">PnL +7.59$</span>
    <span>PF 1.24</span>
    <span>61 trades</span>
  </div>
  ...
</div>
```

---

## 🔧 Pour Personnaliser

### **Ajouter une nouvelle donnée:**

**1. Ajouter la donnée dans le Python** (`serve_trade_journal.py`, ligne 681):
```python
"new_field": sym.get('new_field')
```

**2. Afficher dans le JS** (`trade_journal.html`, ligne 557):
```javascript
<div>Nouvelle donnée: ${s.new_field}</div>
```

### **Changer les couleurs:**

Modifiez les CSS variables (lignes 9-18):
```css
--green: #22c55e;   /* Changez cette valeur */
--red: #ef4444;     /* Ou celle-ci */
--amber: #f59e0b;   /* Ou celle-ci */
```

### **Changer le format d'affichage:**

Modifiez le template HTML (lignes 538-559) pour changer l'ordre, ajouter/supprimer des champs, etc.

---

**Status**: 🟢 **Dashboard entièrement fonctionnel — Top 3 automatiquement chargé via API**
