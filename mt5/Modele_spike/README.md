# Spike Chain Modeling — Boom & Crash

Pipeline complet : détection de spikes → matrice de Markov (prior) →
modèle correctif LightGBM → export ONNX → intégration MQL5 dans
`SMC_Universal` (module Spike Chain State Detector).

Testé de bout en bout avec des données synthétiques (généralisation
plausible, pas encore validée sur données réelles).

## Fichiers

| Fichier | Rôle |
|---|---|
| `00_generate_synthetic_data.py` | Génère un historique M1 factice pour tester le pipeline (à ignorer une fois tes vraies données branchées) |
| `01_spike_detection.py` | Détecte les spikes (seuil dynamique basé sur l'ATR) et extrait les features par événement |
| `02_markov_baseline.py` | Construit la matrice de transition Markov (prior simple + prior binné par amplitude) |
| `03_train_correction_model.py` | Entraîne le modèle LightGBM (validation temporelle TimeSeriesSplit) et exporte en ONNX |
| `04_verify_onnx.py` | Vérifie que l'inférence ONNX correspond au modèle natif avant déploiement |
| `SpikeChainPredictor.mqh` | Classe MQL5 prête à inclure dans `SMC_Universal.mq5` |

## Étape suivante — brancher tes vraies données

1. Exporte ton historique M1 Boom1000, Boom500, Crash1000, Crash500 depuis
   MT5 (Historical Center → Export) ou ton flux Kaggle habituel, au format
   CSV avec colonnes `time, open, high, low, close, volume`.

2. Lance le pipeline pour chaque symbole :
   ```bash
   python 01_spike_detection.py --input boom1000_M1.csv --symbol BOOM1000 --output spikes_boom1000.csv
   python 02_markov_baseline.py --input spikes_boom1000.csv --output markov_boom1000.json
   python 03_train_correction_model.py --input spikes_boom1000.csv --markov markov_boom1000.json --output_dir models/boom1000
   python 04_verify_onnx.py --model_dir models/boom1000 --input spikes_boom1000.csv --markov markov_boom1000.json
   ```
   Répète pour `crash1000`, `boom500`, `crash500`.

3. Points de vigilance sur données réelles (contrairement au synthétique) :
   - **Volume d'événements** : si tu as moins de ~500 spikes par symbole,
     la CV sera bruitée — élargis la période d'historique ou baisse
     légèrement `--spike_atr_mult` (défaut 3.0) pour capter plus d'événements.
   - **Non-stationnarité** : Deriv ajuste parfois les paramètres de génération
     des indices synthétiques. Réentraîne périodiquement (ex: mensuel) plutôt
     que de considérer le modèle comme figé.
   - **Fuite temporelle (leakage)** : `TimeSeriesSplit` est déjà utilisé —
     ne le remplace pas par un split aléatoire, ça donnerait une accuracy
     artificiellement gonflée.
   - **Intégration avec ton RAE existant** : si tu veux injecter le régime
     latent RAE comme feature supplémentaire, ajoute une colonne
     `rae_regime` dans le CSV de spikes (module 1) et rajoute-la dans
     `FEATURE_COLUMNS` du module 3 — le pipeline Markov + LightGBM + export
     ONNX reste inchangé.

4. Copie les `.onnx` générés dans `MQL5/Files/` de ton terminal, recopie les
   valeurs `simple_transition` du JSON Markov dans l'appel `Init()` du
   `.mqh`, et branche `PredictNextSpikeUpProbability()` dans la logique de
   ton EA (filtre de signal, ajustement de lot, ou nouveau critère du GOM
   AI pipeline).

## Interprétation des résultats du test synthétique

Sur les données factices : ~78–80% d'accuracy en validation croisée
temporelle. **Ce chiffre est artificiellement élevé** car j'ai injecté un
biais directionnel fort et constant dans la génération synthétique — la
vraie difficulté (et le vrai intérêt du modèle) apparaîtra sur données
réelles, où le "edge" sera probablement plus modeste (ex: 55-65% sur la
prédiction directionnelle serait déjà exploitable si bien calibré). Ne
prends donc pas les 80% comme référence de performance attendue.
