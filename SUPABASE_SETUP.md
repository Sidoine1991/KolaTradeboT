# Configuration Supabase pour les Niveaux de Support/Résistance

## 🎯 Objectif

Brancher les vrais niveaux de support/résistance du marché dans le robot de trading MT5 pour remplacer les calculs théoriques qui ne reflètent pas la réalité.

## 📋 Prérequis

1. **Compte Supabase** - Créer un compte sur https://supabase.com
2. **Python 3.8+** - Pour les scripts de mise à jour
3. **MetaTrader 5** - Pour récupérer les données historiques
4. **Accès API** - Clés API Supabase

## 🚀 Installation

### 1. Créer la base de données

```bash
# Exécuter la migration SQL dans Supabase
# Fichier: supabase/migrations/20250311_support_resistance_levels.sql
```

### 2. Installer les dépendances Python

```bash
pip install supabase pandas numpy requests MetaTrader5 python-dotenv
```

### 3. Configurer les variables d'environnement

```bash
# Copier le fichier d'exemple
cp .env.supabase.example .env.supabase

# Éditer avec vos vraies valeurs
nano .env.supabase
```

### 4. Remplir les variables

```bash
# Configuration Supabase
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_KEY=your-supabase-anon-key
SUPABASE_SERVICE_KEY=your-supabase-service-role-key

# Configuration MT5
MT5_LOGIN=your-mt5-login
MT5_PASSWORD=your-mt5-password
MT5_SERVER=your-mt5-server
```

## 📊 Mise à jour des niveaux S/R

### Script automatique

```bash
# Lancer l'analyse complète
python backend/update_support_resistance.py
```

Le script va:
- ✅ Se connecter à MT5
- ✅ Analyser chaque symbole (Boom/Crash)
- ✅ Calculer les vrais niveaux S/R
- ✅ Stocker dans Supabase avec scores de force

### Test de connexion

```bash
# Vérifier que tout fonctionne
python backend/test_supabase_connection.py
```

## ⚙️ Configuration MT5

### 1. Compiler le robot

```mql5
// Dans les inputs du robot
SupabaseUrl = "https://your-project-id.supabase.co"
SupabaseApiKey = "your-supabase-anon-key"
```

### 2. Activer WebRequest

MT5 → Outils → Options → Expert Advisors → Autoriser WebRequest

### 3. Ajouter l'URL

Ajouter `https://your-project-id.supabase.co` dans la liste des URL autorisées.

## 📈 Fonctionnement

### 1. Priorité Supabase

Le robot maintenant:
1. **🥇 Supabase** - Vrais niveaux du marché (si configuré)
2. **🥈 EMA** - Niveaux dynamiques (fallback)
3. **🥉 Calculs locaux** - Dernier recours

### 2. Format des données

```json
{
  "id": 1,
  "symbol": "Boom 1000 Index",
  "support": 1000.50,
  "resistance": 1002.00,
  "timeframe": "M1",
  "strength_score": 85.5,
  "touch_count": 12,
  "last_touch": "2025-03-11T10:30:00Z"
}
```

### 3. Score de force

Le score (0-100) est calculé avec:
- **Nombre de touches** (40 pts max)
- **Touches récentes** (20 pts max)
- **Volume au niveau** (25 pts max)
- **Proximité du prix** (15 pts max)

## 🔧 Maintenance

### Mise à jour quotidienne

```bash
# Script à lancer toutes les heures
crontab -e

# Ajouter:
0 * * * * cd /path/to/tradbot && python backend/update_support_resistance.py
```

### Monitoring

Les logs MT5 affichent:
- ✅ Connexion Supabase réussie
- 📊 Niveaux récupérés
- 🔄 Fallback si nécessaire
- ❌ Erreurs éventuelles

## 🎯 Résultats attendus

### Avantages

- ✅ **Vrais niveaux S/R** - Basés sur l'historique réel
- ✅ **Scores de force** - Pour hiérarchiser les niveaux
- ✅ **Fallback automatique** - Si Supabase indisponible
- ✅ **Performance** - Cache et requêtes optimisées

### Logs typiques

```
🌐 Requête Supabase S/R pour: Boom 1000 Index (M1)
📊 Supabase S/R - Support: 1000.50000 | Résistance: 1002.00000
📍 Support Supabase trouvé - Distance: 0.00150
✅ Niveau Supabase sélectionné: SUPABASE_SUPPORT @ 1000.50000
```

## 🚨 Dépannage

### Erreurs communes

1. **WebRequest bloqué**
   - Vérifier options MT5
   - Ajouter URL dans liste autorisée

2. **Clé API invalide**
   - Vérifier variables d'environnement
   - Tester avec script de connexion

3. **Table vide**
   - Exécuter script de mise à jour
   - Vérifier connexion MT5

### Debug

```mql5
// Activer les logs détaillés
Print("🔍 DEBUG - Supabase URL: ", SupabaseUrl);
Print("🔍 DEBUG - API Key length: ", StringLen(SupabaseApiKey));
```

## 📚 Documentation

- [Docs Supabase](https://supabase.com/docs)
- [API Reference](https://supabase.com/docs/reference)
- [Python Client](https://supabase.com/docs/reference/python)

## 🎉 Conclusion

Une fois configuré, votre robot utilisera les **vraies niveaux de support/résistance du marché** au lieu de calculs théoriques, ce qui devrait considérablement améliorer la précision des ordres limit et la performance globale du trading.

---

**Note:** Les niveaux S/R sont mis à jour automatiquement toutes les heures, mais vous pouvez lancer le script manuellement pour des mises à jour immédiates après des mouvements de marché importants.
