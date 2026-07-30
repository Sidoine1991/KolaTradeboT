#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
train_spike_hazard.py
======================
Point d'entree CLI qui relie tout le pipeline:

  CSV (ExportTickHistory.mq5) -> spike_hazard.py -> {symbol}_spike_hazard.json
  (fichier lu ensuite par ai_server.py / ml/spike_hazard.is_model_validated)

Usage:
    python train_spike_hazard.py --csv Boom500_ticks_20260101_20260201.csv \
                                  --symbol Boom500 \
                                  --models-dir /tmp/models \
                                  --permutations 200

IMPORTANT: ce script est volontairement VERBEUX sur le verdict. Il n'ecrit
le fichier modele que si l'effet est a la fois statistiquement significatif
(LR test) ET economiquement exploitable (seuil relative_effect). Sinon il
affiche le resultat mais n'active RIEN cote EA — conformement a la porte de
securite is_model_validated().
"""

import argparse
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from spike_hazard import (
    load_ticks_csv,
    load_bar_csv,
    detect_spikes,
    build_hazard_dataset,
    fit_hazard_model,
    permutation_test,
    save_hazard_result,
    MIN_TICKS_FOR_FIT,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("train_spike_hazard")


def main():
    parser = argparse.ArgumentParser(description="Entraine et valide le modele de hazard spike (etage 1).")
    parser.add_argument("--csv", required=True, help="CSV exporte par ExportTickHistory.mq5 (tick) ou export M1 standard MT5 (date,hour,close,...)")
    parser.add_argument("--bar-level", action="store_true", help="CSV en M1/OHLC au lieu de tick-level (resolution grossiere, cf avertissement)")
    parser.add_argument("--symbol", required=True, help="Nom du symbole (ex: Boom500)")
    parser.add_argument("--models-dir", default="/tmp/models", help="Dossier de sortie du modele (doit matcher MODELS_DIR de ai_server.py)")
    parser.add_argument("--k-sigma", type=float, default=8.0, help="Seuil de detection spike (x sigma local)")
    parser.add_argument("--permutations", type=int, default=200, help="Nb de permutations pour le test complementaire")
    parser.add_argument("--min-effect", type=float, default=None,
                         help="Override du seuil d'exploitabilite economique (defaut module: 0.15 = 15%%). "
                              "Ex: --min-effect 0.08 pour valider un effet plus modeste mais statistiquement confirme.")
    args = parser.parse_args()

    if args.min_effect is not None:
        import spike_hazard as _sh
        logger.warning(f"Override du seuil d'exploitabilite: {_sh.ECONOMIC_EFFECT_THRESHOLD:.0%} -> {args.min_effect:.0%}")
        _sh.ECONOMIC_EFFECT_THRESHOLD = args.min_effect

    if args.bar_level:
        logger.warning(
            "Mode --bar-level: resolution M1, PAS tick-level. Un effet a l'echelle de "
            "quelques secondes/ticks serait invisible ici. Voir avertissement dans le README."
        )

    logger.info(f"Chargement depuis {args.csv} ...")
    df = load_bar_csv(args.csv) if args.bar_level else load_ticks_csv(args.csv)
    logger.info(f"{len(df):,} lignes chargees.")

    if len(df) < MIN_TICKS_FOR_FIT:
        logger.error(
            f"Dataset trop petit ({len(df):,} < {MIN_TICKS_FOR_FIT:,}). "
            "Exporte une periode plus longue avant de continuer — sinon le "
            "resultat serait statistiquement non fiable."
        )
        sys.exit(1)

    logger.info("Detection des spikes (seuil adaptatif MAD) ...")
    is_spike = detect_spikes(df, k_sigma=args.k_sigma)
    n_spikes = int(is_spike.sum())
    logger.info(f"{n_spikes:,} spikes detectes ({100*n_spikes/len(df):.4f}% des ticks).")

    if n_spikes < 200:
        logger.error(
            f"Trop peu de spikes detectes ({n_spikes}) pour un test statistique fiable. "
            "Augmente la periode d'export ou verifie le seuil --k-sigma."
        )
        sys.exit(1)

    logger.info("Construction du dataset de hazard (pooled logistic) ...")
    data = build_hazard_dataset(df, is_spike)

    logger.info("Ajustement du modele + LR test vs modele nul (memoryless) ...")
    result = fit_hazard_model(data)

    logger.info("=" * 70)
    logger.info(f"N observations       : {result.n_obs:,}")
    logger.info(f"N events (spikes)    : {result.n_events:,}")
    logger.info(f"LR statistic         : {result.lr_statistic:.3f}")
    logger.info(f"LR p-value           : {result.lr_pvalue:.6f}")
    logger.info(f"Significatif (LR)    : {result.significant}")
    logger.info(f"Direction detectee   : {result.direction}  (clustering=risque elevee pres d'un spike, cooldown=risque baisse)")
    logger.info(f"Hazard baseline      : {result.hazard_baseline*100:.4f}%  (echantillon: {result.baseline_n_obs:,} obs)")
    logger.info(f"Hazard min post-spike: {result.hazard_min_early*100:.4f}%")
    logger.info(f"Effet relatif        : {result.relative_effect*100:.2f}%")
    logger.info(f"EXPLOITABLE          : {result.economically_exploitable}")
    logger.info("=" * 70)

    if result.significant:
        logger.info(f"Lancement du test de permutation ({args.permutations} permutations) — "
                     "verification complementaire, plus lent ...")
        perm_p = permutation_test(data, n_permutations=args.permutations)
        logger.info(f"Permutation test p-value: {perm_p:.4f}")
        if perm_p > 0.01:
            logger.warning(
                "Le LR test etait significatif mais le test de permutation ne confirme PAS "
                "l'effet (p={:.4f} > 0.01). Le modele parametrique (spline) a probablement "
                "mal specifie la forme de f(n). VERDICT: on ne valide PAS le modele.".format(perm_p)
            )
            result.economically_exploitable = False

    models_dir = Path(args.models_dir)
    if result.economically_exploitable:
        path = save_hazard_result(result, args.symbol, models_dir)
        logger.info(f"✅ MODELE VALIDE ET SAUVEGARDE: {path}")
        logger.info("   -> ai_server.py va maintenant servir /spike-hazard pour ce symbole.")
    else:
        logger.info("❌ MODELE NON VALIDE — rien n'est sauvegarde, rien n'est active cote EA.")
        logger.info("   Verdict honnete: pas de cooldown exploitable detecte sur cette periode.")


if __name__ == "__main__":
    main()
