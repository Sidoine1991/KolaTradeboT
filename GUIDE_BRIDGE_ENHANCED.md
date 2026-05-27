# Guide TradBOT Bridge Enhanced V2

## 🎯 Nouvelles Fonctionnalités

Le bridge TradingAgents a été amélioré avec 5 fonctionnalités majeures:

### ✅ 1. Multi-langue
- Français (FR)
- English (EN)
- Español (ES)
- العربية (AR)

### ✅ 2. Types de rapport
- **Résumé** (5 pages max) : Sections essentielles uniquement
- **Complet** (sans limite) : Toutes les sections d'analyse

### ✅ 3. Calcul lot size adapté au budget
- **Petit compte (10$)** : Risque 2% par trade
- **Compte moyen (50$)** : Risque 2% par trade
- **Grand compte (200$+)** : Risque 1.5% par trade

Le lot size est calculé automatiquement selon:
- Prix d'entrée
- Stop Loss
- Taille du compte
- Pip value du symbole

### ✅ 4. Signal de trade obligatoire
Chaque rapport contient OBLIGATOIREMENT:
- Direction (BUY/SELL)
- Stop Loss (SL)
- Take Profit 1 (TP1)
- Take Profit 2 (TP2)
- Lot size calculé
- Risque en USD

### ✅ 5. Envoi automatique WhatsApp
Une fois le rapport Word sauvegardé, il est automatiquement envoyé sur WhatsApp au numéro du propriétaire.

---

## 🚀 Utilisation

### Mode 1: Wizard Interactif (Recommandé)

```bash
bridge_enhanced.bat
```

ou

```bash
python Python/tradbot_bridge_enhanced.py --wizard
```

Le wizard vous guidera pour choisir:
1. 📝 **Langue du rapport** (FR, EN, ES, AR)
2. 📄 **Type de rapport** (Résumé 5 pages / Complet)
3. 💰 **Taille de compte** (10$, 50$, 200$+)
4. 📱 **Envoi WhatsApp** (Oui/Non)
5. 📊 **Symbole MT5** (XAUUSD, EURUSD, etc.)

### Mode 2: Arguments en ligne de commande

```bash
python Python/tradbot_bridge_enhanced.py \
  --symbol XAUUSD \
  --lang FR \
  --report-type summary \
  --account medium
```

**Arguments disponibles:**

| Argument | Valeurs | Description |
|----------|---------|-------------|
| `--symbol` | XAUUSD, EURUSD, etc. | Symbole MT5 |
| `--lang` | FR, EN, ES, AR | Langue du rapport |
| `--report-type` | summary, full | Type de rapport |
| `--account` | small, medium, large | Taille de compte |
| `--no-whatsapp` | (flag) | Désactiver envoi WhatsApp |
| `--auto` | (flag) | Pas de confirmation interactive |
| `--no-pending` | (flag) | Rapport seul, pas d'ordre MT5 |

---

## 📊 Exemples d'Utilisation

### Exemple 1: Rapport XAUUSD en français, compte moyen

```bash
python Python/tradbot_bridge_enhanced.py \
  --symbol XAUUSD \
  --lang FR \
  --report-type summary \
  --account medium
```

**Résultat:**
- Rapport en français
- 5 pages maximum
- Lot size calculé pour compte de 50$
- Envoi automatique WhatsApp ✅

### Exemple 2: Rapport EURUSD en anglais, compte large, complet

```bash
python Python/tradbot_bridge_enhanced.py \
  --symbol EURUSD \
  --lang EN \
  --report-type full \
  --account large \
  --no-whatsapp
```

**Résultat:**
- Rapport en anglais
- Toutes les sections
- Lot size pour compte 200$+
- Pas d'envoi WhatsApp ❌

### Exemple 3: Mode wizard pour débutants

```bash
bridge_enhanced.bat
```

Interface interactive complète avec explications.

---

## 📄 Structure du Rapport Word Amélioré

### Section 1: Page de Titre
- Titre traduit dans la langue choisie
- Date d'analyse
- Symbole analysé

### Section 2: Signal TradingAgents
- Rating brut
- Décision (BUY/SELL/HOLD)
- Prix actuel
- ATR (volatilité)
- Confiance (%)

### Section 3: Signaux de Trading Proposés (2 signaux)

#### Signal 1 — Conservateur
- Type d'ordre (MARKET / PENDING)
- Direction (BUY / SELL)
- Prix d'entrée
- Stop Loss (avec pips de risque)
- Take Profit (avec pips de gain)
- Ratio R/R

#### Signal 2 — Agressif
- Mêmes informations que Signal 1

### Section 4: **NOUVEAU** - Taille de Position Recommandée

Tableau avec:
- **Taille de compte**: 10$ / 50$ / 200$+
- **Capital**: Montant total
- **Risque par trade**: 2% ou 1.5%
- **Montant du risque**: En USD
- **Taille de position**: Lot size calculé
- **Perte potentielle**: Si SL touché
- **Gain potentiel**: Si TP1/TP2 atteint

**Exemple:**

| Item | Valeur |
|------|--------|
| Taille de compte | Compte moyen (50$) |
| Capital | $50.00 |
| Risque par trade | 2% |
| Montant du risque | $1.00 |
| Taille de position | 0.02 lot |
| Perte potentielle | -$1.00 (si SL touché) |
| Gain potentiel TP1 | +$2.00 (R/R 1:2) |
| Gain potentiel TP2 | +$3.00 (R/R 1:3) |

### Section 5: Analyse Détaillée (selon type de rapport)

**Si Résumé (5 pages max):**
- Analyse technique (synthèse)
- Sentiment du marché
- Conclusion et recommandations

**Si Complet (sans limite):**
- Analyse technique complète
- Analyse fondamentale
- Sentiment du marché (social, news)
- Analyse des indicateurs
- Gestion du risque
- Conclusion et recommandations

### Section 6: Footer
- Disclaimer traduit
- "Généré par TradBOT" dans la langue choisie

---

## 💰 Calcul Lot Size — Détails Techniques

### Formule

```
Lot Size = Risk (USD) / (SL Distance (pips) × Pip Value)
```

### Exemples

#### Exemple 1: XAUUSD, Compte 50$

- **Capital**: 50$
- **Risque**: 2% = 1$
- **Entry**: 4570
- **Stop Loss**: 4590
- **SL Distance**: 20$ = 200 pips (or: pip size = 0.1)
- **Pip Value**: 0.01$ par pip pour 0.01 lot

**Calcul:**
```
Lot = 1$ / (200 pips × 0.01$) = 1 / 2 = 0.50 lot
```

Mais avec capital limité à 50$, lot max = 0.05 (conservateur).

**Lot final**: 0.05 lot

#### Exemple 2: EURUSD, Compte 200$

- **Capital**: 200$
- **Risque**: 1.5% = 3$
- **Entry**: 1.0500
- **Stop Loss**: 1.0450
- **SL Distance**: 50 pips
- **Pip Value**: 10$ par lot standard

**Calcul:**
```
Lot = 3$ / (50 pips × 10$) = 3 / 500 = 0.006 lot → arrondi à 0.01 lot (min MT5)
```

**Lot final**: 0.01 lot

---

## 📱 Envoi WhatsApp Automatique

### Configuration

Le script utilise `send_tradingagents_report.py` en arrière-plan.

**Pré-requis:**
1. PsychoBot connecté sur Render
2. Endpoint `/send-file` fonctionnel
3. Numéro WhatsApp configuré: `+2290196911346`

### Processus

1. Rapport Word sauvegardé dans `D:\Dev\TradBOT\reports\`
2. Upload sur tmpfiles.org (7 jours)
3. Appel PsychoBot `/send-file`
4. PsychoBot télécharge et envoie via Baileys
5. Confirmation dans le terminal ✅

### Désactiver

```bash
python Python/tradbot_bridge_enhanced.py \
  --symbol XAUUSD \
  --no-whatsapp
```

---

## 🛠️ Dépannage

### Erreur: `ModuleNotFoundError: No module named 'bridge_enhancements'`

Le fichier `bridge_enhancements.py` doit être dans `Python/`.

**Fix:**
```bash
cd D:/Dev/TradBOT
ls Python/bridge_enhancements.py  # Vérifier présence
```

### Erreur: `Script WhatsApp introuvable`

Le fichier `send_tradingagents_report.py` est absent.

**Fix:**
```bash
cd D:/Dev/TradBOT
ls Python/send_tradingagents_report.py  # Vérifier présence
```

### Erreur: `HTTP 503 Bot not connected to WhatsApp`

PsychoBot est déconnecté.

**Fix:**
1. Aller sur https://psychobot-1si7.onrender.com
2. Scanner le QR code avec WhatsApp
3. Réessayer

### Erreur: TradingAgents venv introuvable

Le venv Python de TradingAgents n'est pas installé.

**Fix:**
```bash
cd "D:\Dev\Depot Github\TradingAgents-main"
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
```

---

## 📋 Checklist avant utilisation

- [ ] TradingAgents venv installé
- [ ] AI Server lancé (`python ai_server.py`)
- [ ] PsychoBot connecté sur WhatsApp
- [ ] Fichiers `bridge_enhancements.py` et `send_tradingagents_report.py` présents
- [ ] Variables d'environnement `.env` configurées

---

## 🎯 Résumé des Commandes

| Action | Commande |
|--------|----------|
| **Mode wizard** | `bridge_enhanced.bat` |
| **Rapport FR, compte moyen** | `python Python/tradbot_bridge_enhanced.py --symbol XAUUSD --lang FR --account medium` |
| **Rapport EN, complet, grand compte** | `python Python/tradbot_bridge_enhanced.py --symbol EURUSD --lang EN --report-type full --account large` |
| **Rapport ES, sans WhatsApp** | `python Python/tradbot_bridge_enhanced.py --symbol GBPUSD --lang ES --no-whatsapp` |
| **Aide** | `python Python/tradbot_bridge_enhanced.py --help` |

---

## 📊 Comparaison Bridge V1 vs V2

| Fonctionnalité | Bridge V1 | Bridge V2 Enhanced |
|----------------|-----------|-------------------|
| Langue | FR uniquement | FR, EN, ES, AR |
| Type rapport | Complet uniquement | Résumé (5p) / Complet |
| Lot size | Fixe ou manuel | Calculé selon budget |
| Signal SL/TP | Basique | Obligatoire avec TP1/TP2 |
| WhatsApp | Manuel | Automatique |
| Design Word | Standard | Amélioré |
| Compte multiple | Non | Oui (10$, 50$, 200$+) |

---

## ✅ Prochaines Étapes

Une fois familiarisé avec le bridge enhanced:

1. Lancer avec `--wizard` pour première utilisation
2. Noter vos préférences (langue, compte, type rapport)
3. Utiliser arguments CLI pour automatisation
4. Vérifier rapports reçus sur WhatsApp
5. Ajuster taille de compte selon capital réel

---

**Créé le**: 2026-05-25  
**Version**: 2.0 Enhanced  
**Auteur**: TradBOT Team
