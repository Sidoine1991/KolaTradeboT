# 🔧 Instructions pour Corriger le Dashboard

## 🚨 **Problèmes Identifiés**

### **1. Erreurs Supabase (Status 400)**
- **Cause** : Syntaxe de filtre de date incorrecte
- **Erreur** : `date=gte.2025-10-31&date=lte.2025-11-29`
- **Solution** : Utiliser `&and=(date.gte.XX,date.lte.YY)`

### **2. Erreurs API Backend (Status 500)**
- **Cause** : Erreur interne serveur
- **Solution** : Ajouter gestion d'erreur et mode dégradé

## 🛠️ **Étapes de Correction**

### **Étape 1: Corriger les requêtes Supabase**

Dans `agent-dashboard.html`, trouver la fonction `loadPlanifications` et remplacer :

```javascript
// ❌ CODE INCORRECT
const url = `planifications?select=...&date=gte.${startDate}&date=lte.${endDate}`;

// ✅ CODE CORRIGÉ
const url = `planifications?select=...&and=(date.gte.${startDate},date.lte.${endDate})`;
```

### **Étape 2: Ajouter gestion d'erreur pour les rapports**

Dans `loadMonthlyReport`, ajouter :

```javascript
async function loadMonthlyReport(agentId, month, year, projectName) {
    try {
        const response = await fetch(
            `/api/agents/monthly-report?agentId=${agentId}&month=${year}-${month}&ai=1&project_name=${encodeURIComponent(projectName)}`
        );
        
        if (!response.ok) {
            if (response.status === 500) {
                // Mode dégradé
                console.warn('Serveur surchargé, utilisation du mode dégradé');
                return {
                    success: false,
                    message: 'Rapport temporairement indisponible',
                    data: getDefaultReportData(agentId, month, year)
                };
            }
            throw new Error(`HTTP ${response.status}`);
        }
        
        return await response.json();
    } catch (error) {
        console.error('Erreur lors du chargement du rapport:', error);
        showUserMessage('Le serveur est temporairement indisponible. Veuillez réessayer plus tard.');
        return null;
    }
}
```

### **Étape 3: Ajouter retry automatique**

```javascript
async function fetchWithRetry(url, options = {}, maxRetries = 3) {
    for (let i = 0; i < maxRetries; i++) {
        try {
            const response = await fetch(url, options);
            if (response.ok) return response;
            
            // Si erreur 500, attendre avant de réessayer
            if (response.status === 500 && i < maxRetries - 1) {
                await new Promise(resolve => setTimeout(resolve, 2000 * (i + 1)));
                continue;
            }
            
            return response;
        } catch (error) {
            if (i === maxRetries - 1) throw error;
            await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
        }
    }
}
```

### **Étape 4: Optimiser le chargement**

```javascript
// Charger les rapports en parallèle avec timeout
async function loadAllReports(agentIds, month, year) {
    const promises = agentIds.map(async (agentId) => {
        try {
            const timeoutPromise = new Promise((_, reject) => 
                setTimeout(() => reject(new Error('Timeout')), 10000)
            );
            
            const reportPromise = generateMonthlyReport(agentId, month, year);
            
            return await Promise.race([reportPromise, timeoutPromise]);
        } catch (error) {
            console.warn(`Échec du chargement pour agent ${agentId}:`, error);
            return null;
        }
    });
    
    return await Promise.allSettled(promises);
}
```

## 🎯 **Solution Immédiate**

### **Option 1: Correction Rapide**
Ajouter ce code dans `agent-dashboard.html` :

```html
<script>
// Corriger les requêtes Supabase
function fixSupabaseQueries() {
    // Remplacer toutes les requêtes incorrectes
    const oldPattern = /date=gte\.[^&]+&date=lte\.[^&]+/g;
    const newPattern = 'and=(date.gte.2025-10-31,date.lte.2025-11-29)';
    
    // Corriger les URLs
    document.querySelectorAll('script').forEach(script => {
        if (script.textContent.includes('planifications?')) {
            script.textContent = script.textContent.replace(oldPattern, newPattern);
        }
    });
}

// Exécuter au chargement
document.addEventListener('DOMContentLoaded', fixSupabaseQueries);
</script>
```

### **Option 2: Mode Dégradé**
Ajouter un indicateur de chargement et message d'erreur :

```html
<div id="loadingIndicator" class="d-none">
    <div class="spinner-border text-primary" role="status">
        <span class="visually-hidden">Chargement...</span>
    </div>
    <p class="mt-2">Chargement des rapports...</p>
</div>

<div id="errorMessage" class="alert alert-warning d-none">
    <i class="fas fa-exclamation-triangle"></i>
    <span id="errorText">Le serveur est temporairement indisponible.</span>
    <button class="btn btn-sm btn-outline-primary ms-2" onclick="retryLoading()">
        <i class="fas fa-redo"></i> Réessayer
    </button>
</div>
```

## 🔄 **Test et Validation**

### **1. Tester les requêtes Supabase**
```javascript
// Dans la console du navigateur
fetch('https://eoamsmtdspedumjmmeui.supabase.co/rest/v1/planifications?select=*&and=(date.gte.2025-10-31,date.lte.2025-11-29)')
    .then(r => r.json())
    .then(data => console.log('✅ Requête OK:', data))
    .catch(e => console.error('❌ Erreur:', e));
```

### **2. Tester l'API de rapports**
```javascript
// Tester avec un agentId connu
fetch('/api/agents/monthly-report?agentId=88&month=2025-11&ai=1')
    .then(r => r.json())
    .then(data => console.log('✅ Rapport OK:', data))
    .catch(e => console.error('❌ Erreur API:', e));
```

## 📊 **Monitoring**

### **Ajouter des logs**
```javascript
// Logger les erreurs pour debugging
function logError(error, context) {
    console.error(`[${new Date().toISOString()}] ${context}:`, error);
    
    // Envoyer à un service de monitoring si disponible
    if (window.errorTracking) {
        window.errorTracking.track(error, { context });
    }
}
```

---

## 🎯 **Résumé des Actions**

1. **Corriger la syntaxe Supabase** : Utiliser `&and=(date.gte.XX,date.lte.YY)`
2. **Ajouter gestion d'erreur 500** : Mode dégradé + retry
3. **Optimiser le chargement** : Timeout + parallélisation
4. **Ajouter UI feedback** : Indicateurs de chargement + messages d'erreur
5. **Tester et monitorer** : Logs + validation

**Après ces corrections, le dashboard devrait fonctionner normalement même en cas de surcharge serveur.**
