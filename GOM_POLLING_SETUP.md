# Configuration du Polling GOM Multi-Symbole

## État Actuel (2026-06-10 08:49)

- ✅ **XAUUSD** : GOM données présentes (polled via `gom_mcp_poller.py`)
- ❌ **Boom/Crash/BTCUSD** : Données WAIT (non encore pollées)

## Problème

Les symboles Boom/Crash et BTCUSD n'ont pas de données GOM car :
1. Le serveur IA retourne `ok=false` quand `verdict=WAIT` (correct)
2. MT5 ignore les réponses `ok=false` (correct)
3. Mais les données ne sont jamais remplies car `gom_mcp_poller.py` n'a jamais polled ces symboles

## Solution

### Option 1: Lancer le Polling Manuel (Rapide)

Depuis Claude Code, lancez:

```bash
python D:/Dev/TradBOT/Python/gom_mcp_poller.py --symbols "Boom 500 Index,Boom 1000 Index,Crash 500 Index,Crash 1000 Index,BTCUSD,ETHUSD" --once
```

Cela va :
1. Changer TradingView chart vers chaque symbole via MCP
2. Lire les indicateurs GOM (Bollinger, Order Blocks, etc.)
3. Écrire dans `data/gom_signal.json`

Résultat: `data/gom_signal.json` sera mis à jour avec les données réelles.

### Option 2: Daemon Continu (Production)

⚠️ En cours de développement. Actuellement, le daemon `gom_poller_daemon.py` existe mais retourne WAIT.

Pour activer le daemon continu en production:
1. Intégrer MCP dans le daemon (utiliser Claude API ou subprocess)
2. Lancer via Windows Task Scheduler ou supervisord
3. Le daemon poll automatiquement tous les 300s

## Prochaines Étapes

1. ✅ Endpoint `/gom-verdict` implémenté ← MT5 peut query n'importe quel symbole
2. ✅ Format `gom_signal.json` par symbole ← Support multi-symbole
3. ✅ MT5 ignore données WAIT ← Pas de faux signaux
4. ⏳ Polling automatique Boom/Crash ← Nécessite Claude MCP continu

## Test Immédiat

Pour remplir les données GOM Boom/Crash/BTCUSD maintenant:

```bash
# Dans Claude Code, lancez:
python D:/Dev/TradBOT/Python/gom_mcp_poller.py --symbols "Boom 500 Index,Crash 500 Index,BTCUSD" --once
```

MT5 affichera alors `connected=true` pour ces symboles au prochain poll.
