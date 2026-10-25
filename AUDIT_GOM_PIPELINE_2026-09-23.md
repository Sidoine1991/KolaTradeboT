# Audit de fiabilité — Serveur IA Python et pipeline de verdict GOM

**Date :** 23/09/2026 — **Périmètre :** `ai_server.py` (1,37 Mo), `mt5_ai_client.py` (204 Ko), `SMC_GOM_Pipeline.mqh` (262 Ko), `SMC_Universal.mq5` — **Aucune modification apportée.**

---

## 1. Résumé de l'architecture

Le système repose sur un serveur FastAPI/uvicorn (`ai_server.py`, point d'entrée `:32298`, écoute `0.0.0.0:8000` par défaut `:6144`) qui joue le rôle de source de vérité pour les verdicts GOM. Les verdicts sont produits par `_gom_finalize_verdict_pipeline()` (`:10501`) : calcul GOMLPineCalculator.deterministic (scoring pondéré → gap/cohérence → verdict brut → uplift MTF → gates Boom/Crash → gate qualité entrée → gate structure SMC → gate réalité prix M1), inversion Weltrade optionnelle (`GOM_WELTRADE_INVERT_ENABLED=False` par défaut `:10490`), et re-gate M1 final `apply_m1_execution_gate` (`:10529`). Le serveur expose les endpoints de décision/trading (`/decision` `:8499`, `/gom-kola-dashboard` `:11493`, `/gom-verdict` `:29168`, `/gom-verdict/webhook` `:29073`, `/gom/poll-targets` `:27078`, `/mt5/ea-heartbeat` `:26751`, `/mt5/live-snapshot` `:26772`) ainsi que des endpoints d'opération sensibles (`/cache/clear`, `/ml/retraining/trigger`, `/pending-order`, `/approval`). Des boucles d'arrière-plan sont lancées au startup (`:5856`) : import historique MT5, pont dashboard, scan opportunités WhatsApp, agents d'intelligence.

Côté MetaTrader, l'EA `SMC_Universal.mq5` intègre `SMC_GOM_Pipeline.mqh` : `SMCGP_PollGOM()` (`:3303`) interroge `/gom-kola-dashboard` en priorité (fallback `/gom-tableau-complete` si source TradingView, fallback cache local <120s `:3494`, et après 3 échecs consécutifs forçage WAIT `:3483`), avec un backoff adaptatif (×1→×6 `:3425`) et une désynchronisation de phase par ChartID (`:3413`). L'OnTimer (`:5991`) déclenche poll GOM, heartbeat (`:2043`), loss-guard (`:2172`), envoi dashboard et exécution pipeline. Côté exécution, `SMC_FinalOpenGate()` (`:8260`) bloque toute entrée si WAIT/OFF, si la direction est opposée au verdict GOM, si la famille Boom/Crash interdit le sens, si M1+M5 ne valident pas, avec anti-hedge et plafonds de positions. Un second client Python indépendant `mt5_ai_client.py` suit une logique différente via `/decision` (whitelist + seuil 80% `:3025`).

---

## 2. Constatations priorisées

### CRITIQUE

**C1 — Serveur : le verdict « stale » (frais jusqu'à 15 min) peut piloter des entrées M1.**
`_gom_verdict_max_age_sec()` renvoie **900 s par défaut** (`ai_server.py:28057`, env `GOM_VERDICT_MAX_AGE_SEC`). Ce seuil est utilisé pour déclarer un verdict « exploitable » aux endpoints d'exécution (`/gom-verdict` : `:29223`, `:29250`, store : `:28076`). Sur du M1/scalping Boom-Crash où un renversement se joue en secondes, un verdict de 5 à 15 min n'est pas fiable. Or MT5 consomme ce serveur comme source de vérité. Ramener le défaut à 60–120 s (aligné sur le cache EA de 120 s, voir C2).

**C2 — EA : le verdict conservé en cache jusqu'à 120 s est utilisé pour trader pendant les pannes HTTP.**
`SMCGP_GetCachedVerdictNum()` retourne `-999` au-delà de **120 s** (`SMC_GOM_Pipeline.mqh:787`). En échec de poll (hors forçage WAIT), le verdict en cache est ré-affecté avec `g_smcGomConnected=true` (`:3498-3505`, `g_smcGomSource="CACHE_STALE_POLL"`). Pendant jusqu'à 120 s, un `GOOD/PERFECT` périmé continue d'autoriser des entrées via `SMC_FinalOpenGate` (`SMC_Universal.mq5:8328`). Un mouvement M1 violent sans serveur → entrée sur un verdict mort. Le forçage WAIT ne s'active qu'au 3e échec (`GOMCacheMaxConsecFails=3` `:681`, pipeline `:3483`).

**C3 — Serveur : `stale` renvoyé au client alors que l'EA ne lit pas ce champ.**
En cas de timeout de calcul (4 s défaut, `GOM_DASHBOARD_WAIT_SEC` `:11570`), `/gom-kola-dashboard` (`:11576-11618`) retourne des données store avec `stale=True`, voire « any-age » jusqu'à 86 400 s pour l'affichage (`:11608`). Or `SMCGP_ParseGOMBody()` (`SMC_GOM_Pipeline.mqh:2688`) ne lit **ni** `stale`, **ni** `cache_age_sec`, **ni** `timestamp` : il ne fiche que `verdict_num`/`verdict`. L'EA peut donc exécuter un verdict explicite `stale`/`stale_very_old` comme s'il était frais.

**C4 — Serveur : « never overwrite GOOD/PERFECT by WAIT » — entrée sur un signal qui vient d'être invalidé par le calcul live.**
`/gom-kola-dashboard` privilégie explicitement le store poller (TTL 300 s) sur le WAIT live : si le calcul live renvoie `verdict_num=0` mais que le store contient un GOOD/PERFECT datant de < 300 s, le serveur renvoie le store (`:11639-11650`, `gate="prefer_store_over_live_wait"`). La doc interne `:10512-10516` reconnaît que ces mécanismes ont produit des « verdict PERFECT fabriqué … en désaccord avec le prix réel ». Même avec les blends désactivés par défaut, ce compromis « store sur WAIT » recrée le problème : le prix a peut-être déjà renversé, l'EA entre quand même.

**C5 — `mt5_ai_client.py` : le serveur Render public est un fallback d'exécution.**
`RENDER_API_URL = https://kolatradebot-7ofl.onrender.com` (`mt5_ai_client.py:20`) est utilisé en secours si `localhost:8000` tombe (`:4054-4055`, `:4101`). Un client auto-trading qui bascule sur un serveur cloud public pour passer des ordres réels est à la fois un point de défaillance externe (latence/indisponibilité du renderer) et une menace de sécurité (décisions pilotées par une autre instance non auditées ici). Si le cloud sert des données périmées (`gom_signal.json` legacy, voir C6), le client trade dessus.

**C6 — Serveur : `gom_signal.json` legacy reste un fallback d'exécution, « souvent périmé ».**
`/gom-verdict` (`:29219-29240`) retombe sur `data/gom_signal.json` en fallback avec la garde d'âge de 900 s (le commentaire dit « legacy — souvent périmé », `:29220`). Un ancien verdict GOOD/PERFECT écrit dans ce fichier par un poller mort peut repartir en exécution tant qu'il est dans la fenêtre de 15 min.

**C7 — Serveur : basculer sur le store à la place du calcul live fou.</Sect>**
`_get_cached_gom_data()` (`:11220-11240`) consulte le store poller en premier avec `GOM_POLLER_STORE_CACHE_SEC` 300 s (`:11229`) avant tout calcul live. Sur une boucle de polling MT5 de 2 s (`SMC_Universal.mq5:4102`), le serveur sert massivement des données de 0 à 300 s sans recalculer, y compris pour les réponses consommées en exécution. La fraîcheur réelle du verdict n'est donc pas garantie par les endpoints.

---

### HAUTE

**H1 — EA : after 900 s of disconnect, limit enforcement stops entirely.**
`SMCGP_EnforceLimitDiscipline()` (`SMC_GOM_Pipeline.mqh:813-819`) : si `!g_smcGomConnected && (TimeCurrent()-g_smcLastGOMPoll)>900`, la fonction « return » sans annuler les ordres LIMIT contre-tendance. Un serveur coupé > 15 min laisse donc des LIMITs en vigueur sans netting de sécurité, pendant que le forçage WAIT d'entrée (`SMC_Universal.mq5:8328`) bloque seulement les nouvelles entrées.

**H2 — Serveur : temps de calcul live long vs timeout court → serve constamment du store.**
`GOM_DASHBOARD_WAIT_SEC` 4 s (`:11570`) et `GOM_VERDICT_COMPUTE_WAIT_SEC` 4 s (`:29197`) vs un calcul live qui, sur une machine chargée, peut dépasser 4 s (fetch MT5 multi-TF documenté comme gênant `:29193-29195`). Conséquence : les branches « serve stale/store » ne sont pas l'exception mais le régime normal sous charge → pitch de verdicts périmés (Cf. C3/C4).

**H3 — EA : timeout HTTP 15 s sur un poll de 2 s.**
`GOM_Timeout_ms=15000` (`SMC_Universal.mq5:4151`) pour 2 s d'intervalle (`:4102`). Si le serveur répond lentement, le thread de timer EA reste bloqué 15 s par requête (WebRequest est bloquant) → pas de polls, perte de heartbeat, et cascade vers C2. Sous charge simultanée de plusieurs graphiques, saturation certaine malgré la désynchronisation de phase.

**H4 — Double définition de `CACHE_DURATION`.**
`ai_server.py:603` (`=45`) puis `ai_server.py:6152` (`=30`). Le cache simplifié des décisions (`:624-642`) est censé stabiliser les décisions sur 45 s mais la redéfinition secondaire à 30 s est celle qui fait foi (le module est exécuté de haut en bas) → caches divergents et TTL non documenté. Deux sources de vérité pour le TTL de décision.

**H5 — Endpoints d'opération sans authentification sur `0.0.0.0:8000`.**
`/cache/clear` (`:21751`), `/ml/retraining/trigger` (`:22220`), `/ml/retraining/stats`, `/pending-order` (`:29655`), `/approval` (`:29746`), `/trading-pause` (`:29709`) sont exposés sur l'interface réseau sans auth. Une personne du LAN (ou une mauvaise config) peut purger les caches, relancer un retraining ML, modifier des ordres pending ou claquer la pause trading — impact direct sur l'exécution.

**H6 — Serveur : `cache/clear` vide le store GOM aussi.**
À vérifier sur `:21751` : purger les caches mémoire pendant une session ouverte efface aussi `_GOM_VERDICT_STORE` (`:27114`) → prochain poll renverra « pas de verdict » / WAIT → blocage d'entrées légitimes (H5 aggrave).

**H7 — `mt5_ai_client.py` : incohérence des seuils de confiance.**
`MIN_CONFIDENCE = 0.65` (`mt5_ai_client.py:29`) vs `execute_trade` qui exige **80 %** (`:3025`) — et retraite 100 % en exécution immédiate + scalping (`:3075-3096`). Le client demande des décisions avec 0.65 mais n'en exécute qu'à 80 % : couche de décision et couche d'exécution ne partagent pas la même règle. Résultat : soit un signal 65-79 % est perdu (opportunité), soit, dans une autre branche, le même seuil est interprété différemment → risque d'exécution d'une décision non conforme à la politique.

---

### MOYENNE

**M1 — Log non pivoté de 640 Mo (`python/ai_server.log`).**
Un fichier `python/ai_server.log` de 640,5 Mo existe (26/07/2026). Le serveur actuel utilise `RotatingFileHandler` (50 Mo × 5, `ai_server.py:4327-4332`) mais l'ancien log n'a jamais été purgé → risque de remplissage disque sur une machine de trading 24/7, et impossibilité d'auditer facilement les anciens incidents (log trop gros pour être lu).

**M2 — Double bascule « Render » dans `mt5_ai_client` pour curls non exécutifs.**
Des appels directs vers Render (métriques, retraining, feedback) restent codés en dur (`mt5_ai_client.py:479`, `:2041`, `:2274`, `:3330`, `:3407`, `:3435`), même si l'exécution passe par localhost. Si le cloud est down, ces features silencieusement ratent, sans fallback local (H5 aggrave).

**M3 — Pas de vérification `timestamp` dans les réponses consommées par l'EA.**
`SMCGP_ParseGOMBody` ignore le champ `timestamp`/`cache_age_sec` (C3). Même en l'absence de champ `stale`, l'EA ne peut pas détecter un verdict horodaté il y a 10 min. Le seul garde-fou est `g_smcLastGOMPoll` (poll réussi) — qui est mis à jour même quand le corps renvoyé est un store périmé (`:3534`).

**M4 — `_gom_calc_inflight`/`_gom_calc_locks` : 12 workers max pour tous les symboles.**
`GOM_DASHBOARD_WORKERS=12` (`:10493-10496`) pour N symboles × TFs. Sous 12+ calculs simultanés, potentiel de queue et de timeouts 4 s (H2) → syndrome store augmenté. La mémoire des exécuteurs n'est pas bornée avec une politique de rejet.

---

### BASSE

**B1 — `_gom_bridge_singleton` / `_get_gom_bridge` marqué DEPRECATED mais toujours référencé.**
`_get_gom_bridge()` (`:11203-11209`) documente le « bridge TradingView MCP inutilisé » ; des résidus peuvent allumer des chemins de compatibilité qui serviront des données mortes.

**B2 — Commentaires et `FIX-DISCORDANCE-02/03` indiquent des fonctions retirées du pipeline mais encore définies.**
`_gom_mtf_uplift_verdict()` conservé « pour compat mais non appelé » (`:10579-10586`) : surface de code morte qui peut être réactivée par erreur (même classe de bug que C4).

**B3 — Multiples copies de sauvegarde du serveur (non auditées, potentiellement exécutées).**
`ai_server_cloud.py`, `ai_server_backup.py`, `ai_server_fixed.py`… aux côtés de `ai_server.py`. Si une version plus ancienne (sans les FIX M1-gate) est lancée à la place, les protections C4/C6 disparaissent silencieusement.

### SECURITÉ — secrets dans le dépôt

**S1 — Clé API AlphaVantage en dur dans le code.**
`ai_server.py:4379` embarque une clé `ALPHAVANTAGE_API_KEY` en valeur par défaut dans `os.getenv`. Même si la variable d'environnement la surcharge en prod, la clé est en clair dans le repo (déjà poussée sur un dépôt Git avec historique) et doit être révoquée + purgée de l'historique.

**S2 — Multiples fichiers `.env*` présents sur le disque (dont un backup).**
`python/.env.backup_20260602` (166 o, 02/06/2026), `/.env` (232 o), `/.env.local` (161 o), `/.env.pipeline` (880 o), `/.env.supabase` (1141 o), `/.env.supabase.test` (676 o). Seuls `/.env` et `/.env.example` sont nominativement attendus (`:3733` lit `SUPABASE_URL`/`SUPABASE_PROJECT_ID` via `os.getenv`). Tout fichier `.env.*` sauvegardé coté serveur et hors `.gitignore` est une fuite latente de credentials (valeurs non inspectées ici, par principe). Vérifier `.gitignore` et révoquer les clés des backups.

---

## 3. Fixes recommandés (ordre de priorité)

1. Ramener `GOM_VERDICT_MAX_AGE_SEC` défaut à 60–120 s (`ai_server.py:28057`) et diffuser `stale`/`cache_age_sec`/`timestamp` vers l'EA.
2. Faire lire `stale`/`cache_age_sec` dans `SMCGP_ParseGOMBody` et refuser (WAIT) tout corps dont `stale=true` ou `age>60 s` (`SMC_GOM_Pipeline.mqh:2688`).
3. Supprimer la préférence « store sur live WAIT » (`ai_server.py:11639-11650`) : le live doit gagner, jamais l'inverse.
4. Supprimer le fallback `gom_signal.json` et Render des chemins d'exécution ; le store en mémoire TTL court doit être la seule source.
5. Réduire le timeout perdant `GOM_DASHBOARD_WAIT_SEC`/`GOM_VERDICT_COMPUTE_WAIT_SEC` OU allonger la fenêtre MT5 en cohérence, et mettre un circuit breaker côté EA plus court (1 échec → WAIT) pour l'exécution M1.
6. Authentifier (token en-tête) tous les endpoints de mutation (`/cache/clear`, retraining, pending-orders, approval, pause).
7. Nettoyer `python/ai_server.log` (640 Mo) et ajouter une rotation par taille sur l'instance réelle.
8. Aligner `MIN_CONFIDENCE` et le seuil d'exécution dans `mt5_ai_client.py` et supprimer les appels Render comme backend d'exécution.
9. Révoquer la clé AlphaVantage en dur (`ai_server.py:4379`), purger l'historique Git, et supprimer/ignorer les `.env.backup_20260602`, `.env.supabase`, `.env.supabase.test`, `.env.pipeline`.