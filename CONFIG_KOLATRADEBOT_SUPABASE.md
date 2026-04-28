# Configuration KolaTradeBoT avec Supabase

Ce document mappe votre configuration aux noms de variables attendus par le **serveur IA** (Python) et par l’**EA MT5** (SMC_Universal).

---

## 1. Fichier `.env.supabase` (pour le serveur IA)

Le serveur `ai_server.py` charge le fichier `.env.supabase` au démarrage. Il attend les noms suivants :

| Votre variable      | Variable attendue par ai_server.py | À mettre dans .env.supabase |
|---------------------|------------------------------------|-----------------------------|
| `SUPABASE_URL`      | `SUPABASE_URL`                     | Identique                   |
| `SUPABASE_KEY` ou `SUPABASE_ANON_KEY` | `SUPABASE_ANON_KEY` ou `SUPABASE_SERVICE_KEY` | Utiliser **SUPABASE_ANON_KEY** (clé anon) |
| `SUPABASE_PROJECT_ID` | `SUPABASE_PROJECT_ID`            | Identique                   |
| `DATABASE_URL`      | `DATABASE_URL`                     | Identique (PostgreSQL)      |

**Exemple de contenu pour `.env.supabase`** (à adapter avec vos vraies valeurs, en UTF-8) :

```env
# Supabase - Serveur IA (predictions, model_metrics, trade_feedback)
SUPABASE_URL=https://bpzqnooiisgadzicwupi.supabase.co
SUPABASE_ANON_KEY=<votre_clé_anon_ici>
SUPABASE_PROJECT_ID=bpzqnooiisgadzicwupi

# Base de données (optionnel, pour scripts ou connexion directe)
DATABASE_URL=postgresql://postgres:VOTRE_MOT_DE_PASSE@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require
```

- Remplacez `<votre_clé_anon_ici>` par votre clé (celle que vous aviez dans `SUPABASE_KEY` / `SUPABASE_ANON_KEY`).
- Ne commitez pas `.env.supabase` (il doit rester dans `.gitignore`).

---

## 2. EA MT5 (SMC_Universal) – Support/Résistance Supabase

Pour que l’EA utilise les niveaux **Support/Résistance** (et zones) depuis Supabase :

1. **Paramètres d’entrée de l’EA** (onglet « SUPABASE ») :
   - **SupabaseUrl** : `https://bpzqnooiisgadzicwupi.supabase.co`
   - **SupabaseApiKey** : votre clé anon (la même que `SUPABASE_ANON_KEY`).

2. **Autoriser les requêtes HTTP dans MT5**  
   - Outils → Options → Expert Advisors  
   - Cocher « Allow WebRequest for listed URL »  
   - Ajouter : `https://bpzqnooiisgadzicwupi.supabase.co`

Si ces champs restent vides, l’EA utilise les **calculs locaux** pour S/R (comportement normal). Les décisions IA et les métriques ML passent par le **serveur IA**, pas par une connexion Supabase directe depuis l’EA.

---

## 3. Récapitulatif des rôles

| Composant      | Rôle Supabase |
|----------------|----------------|
| **ai_server.py** | Lit/écrit : `predictions`, `model_metrics`, `trade_feedback` ; optionnellement autres tables. Utilise `SUPABASE_URL` + `SUPABASE_ANON_KEY` (ou `SUPABASE_SERVICE_KEY`) depuis `.env.supabase`. |
| **EA MT5**    | Optionnel : lit `support_resistance_levels` (et zones) si **SupabaseUrl** et **SupabaseApiKey** sont renseignés. Sinon, S/R en local. |

---

## 4. Vérification rapide

- **Serveur IA** : au lancement, si Supabase est bien chargé, les logs ne doivent pas indiquer « Supabase non configuré » pour les écritures/lectures (predictions, feedback, métriques).
- **EA** : si vous avez rempli SupabaseUrl et SupabaseApiKey, après avoir autorisé l’URL en WebRequest, vous devriez voir ponctuellement des messages du type « Données S/R Supabase récupérées » (ou équivalent) au lieu de « S/R: calculs locaux » au premier passage.

---

*Fichier généré pour le projet KolaTradeBoT. Ne pas commiter les clés API.*
