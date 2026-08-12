# Correctif discordance verdict GOM — résumé

## Diagnostic confirmé

Le verdict n'était pas mal pondéré à la source — `GOMLPineCalculator.enrich_record()`
(gom_pine_calculator.py) fait déjà un vrai scoring HTF→M1 pondéré (H4=poids 3, H1=poids 2,
D1=poids 2, M15/M5/M1=poids 1, seuils par classe d'actif). Le problème était :

1. **Bug d'ordre d'exécution** (gom_live_calculator.py) : le contexte M1
   (`bars_since_spike`, `price_direction_5b`, `m1_opp_bars`) était calculé
   **après** `enrich_record()`, alors que `apply_price_reality_gate()` — le
   garde-fou censé empêcher un PERFECT/GOOD figé contre la réalité du prix —
   est appelé en toute dernière étape **à l'intérieur** d'`enrich_record()`.
   Résultat : ce gate tournait toujours sur des champs vides lors de sa
   première évaluation et ne pouvait jamais rien corriger.

   → Test réalisé : spike périmé de 20 bougies M1 + prix reparti contre le
   BUY → **avant** le fix le verdict restait `PERFECT BUY`, **après** le fix
   il passe correctement à `WAIT`.

2. **Triple recalcul divergent** : le verdict était recalculé par 2 pipelines
   indépendants (`build_api_response` côté dashboard, `_gom_finalize_verdict_pipeline`
   côté EA), et ce dernier ré-appelait `_gom_mtf_uplift_verdict()` — une version
   simplifiée, sans pondération H4/H1/D1 ni notion de classe d'actif, du gate déjà
   appliqué correctement dans `enrich_record()`. Ce doublon pouvait réintroduire
   un BUY/SELL que le vrai gate pondéré avait légitimement ramené à WAIT.

## Fichiers livrés

- `gom_live_calculator.py` — patché (FIX-DISCORDANCE-01)
- `ai_server.py` — patché (FIX-DISCORDANCE-02)
- `ai_server.diff`, `gom_live_calculator.diff` — diffs unifiés, à relire avant déploiement

## Ce qui n'a PAS été touché (volontairement)

- `_gom_apply_correction_verdict_wait` : conservé tel quel — ce n'est pas un
  doublon, il downgrade uniquement (jamais d'upgrade) à partir de signaux
  distincts (phase de correction, pente RSI M1, pullback M5) non couverts par
  `apply_price_reality_gate`. Architecture saine : garde-fou qui ne peut que
  réduire le verdict, jamais le contredire à la hausse.
- Le blend prédictif (`GOM_USE_PREDICTIVE_BLEND`) et l'inversion Weltrade
  (GainX/PainX) : logiques légitimes et distinctes, pas la source de la
  discordance rapportée.

## Prochaine étape suggérée

Déployer sur un compte/symbole de test d'abord, comparer les logs
`price_reality_reason` avant/après sur quelques heures pour confirmer que la
cadence BUY/GOOD BUY/PERFECT BUY colle mieux à l'évolution réelle du prix
avant bascule en production sur tous les symboles.
