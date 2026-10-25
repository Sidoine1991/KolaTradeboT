# Analyse des pertes observées le 13 Octobre 2026

## 1. Résumé des événements
- **Téléportations d'IA server (127.0.0.1 :8000)** arrêtée pendant ~5 min à 01:13 UTC 2026‑10‑13; interrompu par une erreur de connexion réseau.
- **GOM** a renvoyé un verdict `WAIT` avec `vn=0` (vu dans les logs 20261013.log). La condition de *cohérence* (`coherence_pct < 40 %`) a bloqué l’entrée.
- **IA HOLD** fallback a été activé (serveur hors‑ligne → `FALLBACK_EMA`) et a fermé les positions *GAIN* en attente de clôture à 01:14 UTC.
- **Stagnation GOM** a maintenu l'état `WAIT` dans la fenêtre de 90 s, ce qui a empêché toute nouvelle entrée.
- **Paramètres de protection** (MaxLoss $ = 1 $ après patch, MinRR = 1,5) ont empêché la prise de position après le coup d’arrêt, conduisant à 4 pertes successives de $ ~1,5‑$ 2 et 4 gains de $ ~1‑$ 3.

## 2. Facteurs clés
| Facteur | Impact | Explication |
|---------|--------|-------------|
| **Downtime de l'IA server** | Bloquage complet | L'E/F 1 ne reçoit pas de verdict fiable; IA HOLD fallback refuse les entrées. |
| **Cohérence < 40 %** | Entrée bloquée | Condition `VP_MinCoherenceBypass` se déclenche lorsqu'une action « GOOD / PERFECT » est accompagnée d’un manque de cohérence. |
| **Stagnation GOM > 90 s** | Entrée suspendue | La fenêtre d'attente dépasse 90 s, empêchant toute entrée même si GOM passe à `GOOD`. |
| **Prise de décision IA HOLD (fallback)** | Fermeture automatique | Avec le serveur hors‑ligne, la logique de `UseIAHoldClose` craint que la position n’atteigne toujours `NO‑CLAINT`. |
| **Protection MaxLoss $** | Limitation du gain | `MaxLossPerTradeDollars=1$` limitait l'excès de perte, forçant la fermeture à $‑1.5 et réglant la variance. |

## 3. Ce qui a changé depuis le patch
- L’exécution d’un *raccourci* de fermeture IA HOLD est maintenant limitée aux positions GAIN XAUUSD lorsque `coherence_pct ≥ 40 %`.
- `MaxLossPerTradeDollars` est passé à 1 $ et `MinRR` à 1,5, ce qui empêche le “chasing” de pertes et réduit le nombre de trades closés à perte.
- Le “anti‑stagnation GOM” attend désormais 10 s avant de passer à `PASS`, masquant la suite d’opportunités `WAIT` non essentielles.

### Résultat attendu
Les prochaines exécutions devraient **ne plus produire de pertes successives** tant que le serveur IA est en ligne et que les réglages de cohérence sont respectés. Revoir le trafic WebSocket/HTTP /port 8000 pour garantir une latence < 5 s est impératif.

---

**Recommandations rapides**
- Redémarrer l’IA server (```python ai_server.py ```). Vérifier que l’endpoint `/decision` répond via ```curl http://127.0.0.1:8000/decision```. 
- Révérifier que le groupe de threads GOM indique `GOM=GOOD` dans les 120 s de localisation du spread.
- Lancer un log `tail -n 2000 logs/20261013.log` après le restart pour confirmer que les logs ne contiennent plus de `VETO` liés à IA HOLD.

---

Co‑Authored‑By: Claude Code <noreply@anthropic.com>