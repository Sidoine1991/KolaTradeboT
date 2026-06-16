# 🚀 DÉMARRER GOM SYNC 10-MINUTES AUTOMATIQUE

## ⚡ QUICK START (2 minutes)

### Option 1: PowerShell (Recommandé)

```powershell
# 1. Right-click PowerShell → "Run as Administrator"
# 2. Copier/coller:

cd D:\Dev\TradBOT
powershell -NoProfile -ExecutionPolicy Bypass -File DEPLOY_10MIN_AUTO.ps1
```

**Résultat attendu:**
```
✅ Task created: \TradBOT\GOM-Sync-10min
✅ State: Ready
✅ Test execution successful
✅ AUTONOMOUS SYSTEM ACTIVE
```

### Option 2: Command Prompt (Direct)

```cmd
cd D:\Dev\TradBOT
install-gom-task.bat
```

**Résultat:** Tâche créée, exécution auto toutes les 10 minutes

---

## 📊 APRÈS DÉPLOIEMENT

### ✅ Vérifier que ça marche

```powershell
# Option 1: Via PowerShell (meilleur)
cd D:\Dev\TradBOT
.\launch-gom-10min.ps1 verify

# Option 2: Direct schtasks
schtasks /query /tn "TradBOT\GOM-Sync-10min" /v
```

Chercher: `State: Ready` ✅

### 📋 Voir les logs

```powershell
# Option 1: Dernières 20 lignes
Get-Content D:\Dev\TradBOT\logs\gom_sync.log -Tail 20

# Option 2: Suivi en temps réel
Get-Content D:\Dev\TradBOT\logs\gom_sync.log -Tail 20 -Wait

# Option 3: CLI launcher
cd D:\Dev\TradBOT
.\launch-gom-10min.ps1 logs
```

### 🚀 Forcer une exécution immédiate

```powershell
schtasks /run /tn "TradBOT\GOM-Sync-10min"
```

Attendez 30 secondes, puis vérifiez les logs.

---

## 📱 CE QUE VOUS RECEVREZ

### Toutes les 10 minutes dans WhatsApp:

```
🎯 **GOM VERDICTS REPORT** 📊
==================================================
🟢 XAUUSD — GOOD BUY | Entry: 6031.70 | SL: 6025.81 | TP: 6038.78 | Coh: 85%
  🟢M1 🟢M5 🟢M15 🟢H1 🟢H4 🟢D1
  🤖 ML: 🟢BUY 92% | acc=85%
🔴 BTCUSD — SELL | Entry: 43200.50 | SL: 43250.00 | TP: 43150.00 | Coh: 78%
  🔴M1 🟢M5 🔴M15 🔴H1 🔴H4 🔴D1
==================================================
📅 2026-06-16 18:00:00 UTC
```

### Quand un ordre est placé:

```
🚀 *MARKET ORDER* — XAUUSD
BUY @ 6031.70 SL=6025.81 TP=6038.78
✅ Ordre placé
```

### Quand une position se ferme:

```
🔴 *GOM WAIT — FERMETURE IMMÉDIATE* — XAUUSD
Verdict GOOD BUY → WAIT
✅ Ordre de fermeture envoyé
```

---

## 🔧 COMMANDES UTILES

| Action | Commande |
|--------|----------|
| **Vérifier le statut** | `.\launch-gom-10min.ps1 verify` |
| **Voir les logs** | `.\launch-gom-10min.ps1 logs` |
| **Exécuter maintenant** | `schtasks /run /tn "TradBOT\GOM-Sync-10min"` |
| **Arrêter la tâche** | `schtasks /end /tn "TradBOT\GOM-Sync-10min"` |
| **Redémarrer la tâche** | `schtasks /run /tn "TradBOT\GOM-Sync-10min"` |
| **Désinstaller** | `schtasks /delete /tn "TradBOT\GOM-Sync-10min" /f` |

---

## 📋 CE QUI S'EXÉCUTE CHAQUE 10 MIN

```
1. Charger verdicts GOM
   └─ Source: MT5 live dashboard (priorité)
   
2. Appliquer les gates
   ├─ Cohérence ≥ 85%
   ├─ Direction Boom/Crash correcte
   ├─ RSI pas extrême
   ├─ M15 pas opposé
   ├─ Fenêtre de trading respectée
   └─ Pas de position déjà ouverte
   
3. Envoyer verdicts au serveur
   └─ POST /gom-verdict à ai_server:8000
   
4. Construire rapport
   ├─ Symbole + Action (emoji)
   ├─ Entry/SL/TP
   ├─ Cohérence %
   ├─ Directions par timeframe
   └─ Score ML advisory
   
5. Envoyer WhatsApp
   ├─ Via AI server (/notify-whatsapp)
   └─ Fallback: PsychoBot Render
   
6. Logger tout
   └─ Fichier: logs/gom_sync.log
```

---

## ❌ DÉPANNAGE

### La tâche ne s'exécute pas

```powershell
# 1. Vérifier le statut
schtasks /query /tn "TradBOT\GOM-Sync-10min" /v

# 2. Réinstaller si nécessaire
cd D:\Dev\TradBOT
.\launch-gom-10min.ps1 fix
```

### Python non trouvé

```powershell
# Vérifier
python --version

# Si absent, ajouter au PATH:
$env:Path += ";C:\Python314"
```

### Aucun WhatsApp reçu

```powershell
# 1. Vérifier AI server
curl http://127.0.0.1:8000/health

# 2. Vérifier logs
Get-Content logs/gom_sync.log | Select-String "ERROR|WhatsApp"

# 3. Tester manuellement
.\launch-gom-10min.ps1 run
```

### Verdicts rejetés par gates

```
[GATE-COH] SYMBOL: cohérence 67% < 85% — ordre ignoré
[GATE-M15] SYMBOL: M15=BEAR opposé à BUY — rejeté
```

**C'est normal!** Les gates protègent contre les faux signaux.

---

## 📊 DOSSIER LOGS

**Emplacement:** `D:\Dev\TradBOT\logs\gom_sync.log`

**Format:**
```
2026-06-16 18:00:00 - INFO - [SYNC] Exécution unique GOM sync...
2026-06-16 18:00:05 - WARNING - [GATE-COH] XAUUSD: cohérence 78% < 85%
2026-06-16 18:00:10 - INFO - [OK] Charge 1 verdicts GOM depuis dashboard
2026-06-16 18:00:15 - INFO - [SEND] XAUUSD → BUY (HTTP 200)
2026-06-16 18:00:20 - INFO - [LOG] Rapport construit (1 signaux actifs)
2026-06-16 18:00:21 - INFO - ✅ Rapport WhatsApp envoyé via AI server
2026-06-16 18:00:21 - INFO - [OK] Exécution unique terminée
```

---

## 📈 STATUT

- **État:** ✅ Prêt à déployer
- **Type:** Automatisation complète 10 minutes
- **Fréquence:** Chaque 10 minutes, 24/7
- **Logs:** Auto-créés, horodatés, complets
- **Rapports:** WhatsApp en temps réel
- **Protections:** 9 gates appliquées (anti-faux-signaux)

---

## 🎯 PROCHAINES ÉTAPES

1. **Déployer:** Exécuter `DEPLOY_10MIN_AUTO.ps1` avec admin
2. **Attendre:** 10 minutes pour la première exécution auto
3. **Vérifier:** Checker les logs et WhatsApp
4. **Monitorer:** Surveiller le fichier de log

---

**Créé:** 2026-06-16  
**Script:** gom_sync_with_report.py v1.0  
**Status:** 🚀 Production Ready
