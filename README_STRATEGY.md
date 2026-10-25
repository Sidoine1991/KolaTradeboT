# F_INX_robot4 — Stratégie Zones IA & Scalping EMA50

## Vue d’ensemble
Robot MT5 avec serveur IA (http://127.0.0.1:8000).  
Objectif : trader entre deux zones IA (BUY/SELL), capturer le rebond ou la cassure, puis scalper sur retours à l’EMA50 en respectant des limites de risque strictes.

## Règles de risque
- Max **2 positions globales** (tous symboles).
- Max **2 positions par symbole** (ex. 1 trade principal + 1 scalp).
- Pas de hedge : si une position existe dans le sens opposé, on la ferme avant d’ouvrir.
- SL/TP toujours posés (validation broker via `ValidateAndAdjustStops`).

## Zones IA (dessin)
- Rectangles semi-transparents : BUY (vert), SELL (rouge), visibles M5/H1/H4.
- Les zones sont persistantes jusqu’à mise à jour de l’IA.

## Stratégie principale (rebond entre zones)
1) Le prix touche la BUY zone → on « arme » un BUY.  
   - Confirmation : N bougies M5 haussières (`AIZoneConfirmBarsM5`).  
   - Entrée BUY, **TP = milieu entre BUY et SELL zone**, **SL = bord inférieur BUY zone**.
2) Le prix touche la SELL zone → on « arme » un SELL.  
   - Confirmation : N bougies M5 baissières.  
   - Entrée SELL, **TP = milieu entre BUY et SELL zone**, **SL = bord supérieur SELL zone**.

## Cassure de zone (tendance)
- Cassure baissière de la BUY zone → SELL de continuation (`AIZONE_BUY_BREAK_SELL`), **SL au bord inf. BUY zone**, **TP milieu**.
- Cassure haussière de la SELL zone → BUY de continuation (`AIZONE_SELL_BREAK_BUY`), **SL au bord sup. SELL zone**, **TP milieu**.

## Scalping EMA50 après rebond / cassure
- Après un rebond validé ou une cassure, à chaque retour du prix sur **EMA50 M5** (pullback) :
  - Si contexte BUY actif → ouvrir un BUY scalp (si < 2 positions sur le symbole).
  - Si contexte SELL actif → ouvrir un SELL scalp.
  - Chaque scalp hérite des mêmes cibles : **TP = milieu entre zones**, **SL = bord de zone correspondant**.
  - Scalp stoppé dès que le TP global (milieu) est atteint ou limite de positions atteinte.

## Fermeture et protections
- Coupure globale optionnelle : `UseGlobalLossStop` (perte cumulée ≤ `GlobalLossLimit` ferme tout).
- Coupure rapide de petits profits (optionnelle) : `UseInstantProfitClose`.
- Cooldown après pertes consécutives (anti-chute) déjà implémenté.

## Paramètres clés (Inputs)
- `UseAIZoneBounceStrategy` (true) : active la stratégie zones.
- `AIZoneConfirmBarsM5` : nb de bougies M5 pour confirmer le rebond.
- `UseInstantProfitClose` : fermer dès profit min (désactivé par défaut).
- `AI_*` : URL/timeout, auto-exec IA, notifications.
- `MaxLimitOrdersPerSymbol`, filtres volume/spread/heure, etc.

## Serveur IA
- Endpoints : `/decision`, `/analysis`, `/time_windows`, `/logs`, `/status`.
- POST `/decision` : renvoie action/confidence/reason (+ info spike).
- Les zones IA sont mises à jour via les analyses H1 → affichées M5/H1/H4.

## Bonnes pratiques d’utilisation
- MT5 : autoriser WebRequest pour `http://127.0.0.1`.
- Lancer le serveur : `python ai_server.py` (venv activé).
- Attacher l’EA sur le symbole, vérifier que `UseAI_Agent = true`, `AI_ServerURL` correct.
- Ne pas dépasser 2 positions actives sur le compte (protection automatique).

