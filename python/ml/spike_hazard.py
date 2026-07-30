# -*- coding: utf-8 -*-
"""
ml/spike_hazard.py
===================
Modèle de hazard discret pour tester l'hypothèse du "refractory period"
(cooldown) post-spike sur indices synthétiques (Boom/Crash, Painx/Gainx).

CE MODULE NE FAIT PAS DE "PATTERN RECOGNITION" SUR BOUGIES.
Il teste une hypothèse précise et falsifiable : la probabilité qu'un spike
survienne au tick suivant dépend-elle du nombre de ticks écoulés depuis le
dernier spike (n) ?

  H0 (memoryless)      : h(n) = constante quel que soit n
  H1 (cooldown réel)   : h(n) a une forme non-plate (creux puis plateau)

Méthode : pooled logistic regression (hazard discret), base de splines
naturelles pour f(n), likelihood-ratio test contre le modèle nul, puis
(si et seulement si H1 est confirmée ET économiquement significative)
un classifieur de direction calibré (étage 2).

Design : chaque fonction publique est pure / testable, et rien n'est
"activé" côté EA tant qu'un artefact modèle validé n'existe pas sur disque
(voir `is_model_validated`). Pas de résultat fantôme envoyé au dashboard.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Optional, Tuple

import numpy as np
import pandas as pd
from scipy import stats

logger = logging.getLogger(__name__)

# ----------------------------------------------------------------------
# Constantes
# ----------------------------------------------------------------------
MAX_N_TICKS = 2000          # horizon max pour la variable "ticks depuis dernier spike"
N_SPLINE_KNOTS = 4          # nœuds de la base de spline naturelle pour f(n)
MIN_TICKS_FOR_FIT = 200_000  # seuil mini de ticks pour tenter un fit (sinon trop bruité)
ECONOMIC_EFFECT_THRESHOLD = 0.15  # réduction relative min de h(n) juste après spike pour être "exploitable"
ALPHA_LR_TEST = 0.01        # seuil de significativité du LR test (conservateur, corrige un peu le multiple-testing)


# ----------------------------------------------------------------------
# 1. Préparation des données tick -> dataset de hazard
# ----------------------------------------------------------------------
def load_ticks_csv(path: str) -> pd.DataFrame:
    """Charge le CSV produit par ExportTickHistory.mq5."""
    df = pd.read_csv(path)
    required = {"time_msc", "bid", "ask"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Colonnes manquantes dans {path}: {missing}")
    df = df.sort_values("time_msc").reset_index(drop=True)
    df["mid"] = (df["bid"] + df["ask"]) / 2.0
    return df


def load_bar_csv(path: str) -> pd.DataFrame:
    """
    Charge un CSV OHLC M1 (export MT5 standard: date,hour,open,high,low,close,tick_volume).
    Utilisé pour l'analyse bar-level (résolution grossière, cf note dans
    fit_hazard_model sur les limites par rapport au tick-level).
    """
    df = pd.read_csv(path)
    required = {"date", "hour", "close"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Colonnes manquantes dans {path}: {missing} (format attendu: date,hour,open,high,low,close,tick_volume)")
    dt = pd.to_datetime(df["date"] + " " + df["hour"], format="%Y.%m.%d %H:%M")
    df = df.assign(dt=dt).sort_values("dt").reset_index(drop=True)
    df["mid"] = df["close"]
    df["time_msc"] = (df["dt"].astype("int64") // 10**6)
    return df


def detect_spikes(df: pd.DataFrame, k_sigma: float = 8.0) -> pd.Series:
    """
    Détecte les ticks de spike via seuil adaptatif basé sur l'écart-type
    des increments tick-à-tick (pas un seuil fixe en pips, qui ne
    généralise pas entre Boom 500 / Boom 1000 / Painx etc.)
    """
    delta = df["mid"].diff().fillna(0.0)
    # écart-type robuste (MAD) pour ne pas être pollué par les spikes eux-mêmes
    mad = (delta - delta.median()).abs().median() * 1.4826
    sigma = mad if mad > 0 else delta.std()
    threshold = k_sigma * sigma
    is_spike = delta.abs() > threshold
    return is_spike


def build_hazard_dataset(
    df: pd.DataFrame,
    is_spike: pd.Series,
    rsi14: Optional[pd.Series] = None,
    rsi7: Optional[pd.Series] = None,
    atr_ratio: Optional[pd.Series] = None,
) -> pd.DataFrame:
    """
    Construit le dataset au format "pooled logistic hazard":
    une ligne par tick, avec:
      - n           : ticks depuis le dernier spike (capé à MAX_N_TICKS)
      - event       : 1 si spike à ce tick, 0 sinon
      - covariables optionnelles (RSI, ATR ratio, heure de session)
    """
    n_rows = len(df)
    n_since = np.zeros(n_rows, dtype=np.int32)
    counter = MAX_N_TICKS  # au départ, on ne sait pas -> traité comme "loin d'un spike"
    spikes_arr = is_spike.to_numpy()

    for i in range(n_rows):
        n_since[i] = min(counter, MAX_N_TICKS)
        if spikes_arr[i]:
            counter = 0
        else:
            counter += 1

    out = pd.DataFrame({
        "n": n_since,
        "event": spikes_arr.astype(int),
    })

    if "time_msc" in df.columns:
        hour = pd.to_datetime(df["time_msc"], unit="ms").dt.hour
        out["session_hour"] = hour.to_numpy()

    if rsi14 is not None:
        out["rsi14"] = rsi14.to_numpy()[:n_rows]
    if rsi7 is not None:
        out["rsi7"] = rsi7.to_numpy()[:n_rows]
    if atr_ratio is not None:
        out["atr_ratio"] = atr_ratio.to_numpy()[:n_rows]

    # Le premier spike de la série n'a pas de "vrai" cooldown de référence -> on l'exclut
    out = out.iloc[1:].reset_index(drop=True)
    return out


# ----------------------------------------------------------------------
# 2. Bins log-espacés pour l'analyse de hazard par comptages
# ----------------------------------------------------------------------
# ATTENTION (bug corrigé, historique conservé pour traçabilité): une
# première version encodait n via une base de spline cubique tronquée puis
# une régression logistique. Deux problèmes découverts en testant sur
# données simulées:
#   1) La base spline est structurellement aveugle aux effets près de n=0
#      (chaque fonction de base démarre plate à son nœud) — précisément la
#      zone où un cooldown post-spike se manifesterait.
#   2) Même corrigée (bins au lieu de spline), la régression logistique
#      restait numériquement instable sur un taux d'événements très faible
#      (bins quasi-vides en événements → risque de divergence du solveur
#      selon la graine aléatoire).
# Remplacement final: comptages bruts par bin log-espacé + test binomial
# exact (voir fit_hazard_model) — déterministe, aucune optimisation itérative.
LOG_BIN_EDGES = np.array([0, 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, MAX_N_TICKS + 1])


# ----------------------------------------------------------------------
# 3. Fit du modèle de hazard + LR test contre le modèle nul
# ----------------------------------------------------------------------
@dataclass
class HazardFitResult:
    n_obs: int
    n_events: int
    lr_statistic: float
    lr_pvalue: float
    significant: bool
    direction: str                  # "clustering" (hazard elevee pres de n=0), "cooldown" (hazard baissee), ou "none"
    hazard_baseline: float          # h(n) moyen "loin" d'un spike (n grand)
    hazard_min_early: float         # h(n) minimum observé pour n petit (post-spike)
    relative_effect: float          # |baseline - early| / baseline (signe porte par 'direction')
    economically_exploitable: bool
    coef_covariates: dict
    n_grid: list
    hazard_curve: list              # h(n) estimé sur une grille de n, pour tracé
    baseline_n_obs: int             # taille de l'echantillon de reference (transparence sur la fiabilite)

    def to_dict(self) -> dict:
        return asdict(self)


def fit_hazard_model(data: pd.DataFrame) -> HazardFitResult:
    """
    Test H0 (memoryless) vs H1 (cooldown) via comptages exacts par bin —
    PAS de régression logistique.

    Historique de la décision (pour traçabilité): une première version
    utilisait une régression logistique poolée sur les bins de n. Testée sur
    données simulées, elle s'est révélée numériquement instable: avec un taux
    d'événements très faible (~0.1-0.5%) et des bins à faible n quasi-vides
    en événements, le solveur pouvait diverger et produire un modèle "complet"
    pire que le modèle nul selon la graine aléatoire — un résultat qui change
    selon le bruit du solveur n'est pas un résultat sur lequel on peut se fier.

    Remplacement: pour chaque bin de n "précoce" (proche d'un spike), test
    binomial exact contre le taux de base observé sur les bins "tardifs"
    (loin d'un spike, régime stationnaire). H1 dirigée: le bin précoce a un
    taux INFÉRIEUR au taux de base (hypothèse du cooldown, pas juste "différent").
    Les p-values des bins précoces sont combinées par la méthode de Fisher.
    Aucune optimisation itérative — le résultat ne dépend que des comptages.
    """
    if len(data) < MIN_TICKS_FOR_FIT:
        raise ValueError(
            f"Dataset trop petit ({len(data)} lignes < {MIN_TICKS_FOR_FIT}); "
            "exporte une période plus longue avant de conclure quoi que ce soit."
        )

    y = data["event"].to_numpy()
    n = data["n"].to_numpy()

    bin_idx = np.digitize(n, LOG_BIN_EDGES) - 1
    bin_idx = np.clip(bin_idx, 0, len(LOG_BIN_EDGES) - 2)
    n_bins = len(LOG_BIN_EDGES) - 1

    counts = np.zeros(n_bins, dtype=np.int64)
    events = np.zeros(n_bins, dtype=np.int64)
    for b in range(n_bins):
        mask = bin_idx == b
        counts[b] = mask.sum()
        events[b] = y[mask].sum()
    rates = np.divide(events, counts, out=np.full(n_bins, np.nan), where=counts > 0)

    # Bins "tardifs" (n grand) = référence du régime stationnaire.
    # Bins "précoces" (n petit) = zone où cooldown OU clustering se manifesterait.
    #
    # BASELINE ROBUSTE (correction post-M1): un simple split par index de bin
    # (ex: les 40% de bins les plus élevés) peut tomber sur un échantillon de
    # référence minuscule si les écarts entre spikes sont rarement grands —
    # observé sur Boom500 M1 réel: seulement 955/790631 barres avaient n>=64,
    # rendant la baseline non fiable (biaisée vers des périodes de calme
    # atypiques). Fix: on part du bin le plus élevé et on remonte jusqu'à
    # cumuler au moins BASELINE_MIN_OBS observations, garantissant une
    # référence statistiquement solide même si ça inclut des bins plus proches
    # de n=0 que prévu initialement.
    BASELINE_MIN_OBS = 20_000
    cum = 0
    split = n_bins
    for b in range(n_bins - 1, -1, -1):
        cum += counts[b]
        split = b
        if cum >= BASELINE_MIN_OBS:
            break
    baseline_bins = list(range(split, n_bins))
    early_bins = list(range(0, split))

    baseline_k = int(events[baseline_bins].sum())
    baseline_n_obs = int(counts[baseline_bins].sum())
    baseline_rate = baseline_k / baseline_n_obs if baseline_n_obs > 0 else float("nan")

    from scipy.stats import binomtest

    def _combined_pvalue(alternative: str) -> float:
        pvals = []
        for b in early_bins:
            if counts[b] == 0 or np.isnan(baseline_rate) or baseline_rate <= 0:
                continue
            res = binomtest(int(events[b]), int(counts[b]), baseline_rate, alternative=alternative)
            pvals.append(max(res.pvalue, 1e-300))  # clip pour éviter log(0) dans Fisher
        if not pvals:
            return 1.0, 0.0
        fstat = -2.0 * float(np.sum(np.log(pvals)))
        return float(stats.chi2.sf(fstat, df=2 * len(pvals))), fstat

    # Test bidirectionnel: on ne présuppose plus le sens de l'effet.
    # "less"    -> hypothèse cooldown (hazard basse près de n=0)
    # "greater" -> hypothèse clustering (hazard élevée près de n=0, confirmé sur M1 réel)
    p_cooldown, stat_cooldown = _combined_pvalue("less")
    p_clustering, stat_clustering = _combined_pvalue("greater")

    if p_clustering <= p_cooldown:
        direction = "clustering"
        combined_pvalue, fisher_stat = p_clustering, stat_clustering
    else:
        direction = "cooldown"
        combined_pvalue, fisher_stat = p_cooldown, stat_cooldown

    significant = combined_pvalue < ALPHA_LR_TEST
    if not significant:
        direction = "none"

    early_rates = rates[early_bins]
    early_rates_valid = early_rates[~np.isnan(early_rates)]
    min_early = float(np.min(early_rates_valid)) if len(early_rates_valid) else baseline_rate

    # Taux poolé sur TOUS les bins précoces (pas le minimum/maximum d'un seul
    # bin, souvent 0 par pur bruit d'échantillonnage quand les comptages sont
    # faibles). C'est ce taux poolé qui sert de mesure d'effet.
    early_k = int(events[early_bins].sum())
    early_n_obs = int(counts[early_bins].sum())
    pooled_early_rate = early_k / early_n_obs if early_n_obs > 0 else float("nan")
    relative_effect = (
        abs(baseline_rate - pooled_early_rate) / baseline_rate
        if baseline_rate and baseline_rate > 0 and not np.isnan(pooled_early_rate) else 0.0
    )
    exploitable = bool(significant and relative_effect >= ECONOMIC_EFFECT_THRESHOLD)

    # Courbe pour affichage/EA: taux empirique par bin (fonction en escalier),
    # centre du bin = moyenne géométrique des bornes (cohérent avec bins log).
    bin_centers = []
    for b in range(n_bins):
        lo, hi = LOG_BIN_EDGES[b], LOG_BIN_EDGES[b + 1]
        bin_centers.append(float(np.sqrt(max(lo, 0.5) * hi)))
    hazard_curve = [float(r) if not np.isnan(r) else 0.0 for r in rates]

    return HazardFitResult(
        n_obs=int(len(data)),
        n_events=int(y.sum()),
        lr_statistic=fisher_stat,
        lr_pvalue=combined_pvalue,
        significant=significant,
        direction=direction,
        hazard_baseline=float(baseline_rate) if not np.isnan(baseline_rate) else 0.0,
        hazard_min_early=min_early,
        relative_effect=float(relative_effect),
        economically_exploitable=exploitable,
        coef_covariates={},  # covariables non utilisées dans ce test robuste (voir note module)
        n_grid=[round(c, 1) for c in bin_centers],
        hazard_curve=[round(h, 6) for h in hazard_curve],
        baseline_n_obs=baseline_n_obs,
    )


def permutation_test(data: pd.DataFrame, n_permutations: int = 200, seed: int = 42) -> float:
    """
    Test de permutation complémentaire au LR test: on mélange aléatoirement
    la colonne 'n' (en gardant 'event' fixe) et on recompte combien de fois
    le LR statistic permuté dépasse celui observé sur les vraies données.
    Protège contre une mauvaise spécification du modèle paramétrique.
    """
    rng = np.random.default_rng(seed)
    observed = fit_hazard_model(data).lr_statistic

    count_exceed = 0
    shuffled = data.copy()
    for _ in range(n_permutations):
        shuffled["n"] = rng.permutation(shuffled["n"].to_numpy())
        try:
            stat = fit_hazard_model(shuffled).lr_statistic
        except Exception:
            continue
        if stat >= observed:
            count_exceed += 1

    return (count_exceed + 1) / (n_permutations + 1)  # p-value avec correction +1/+1


# ----------------------------------------------------------------------
# 4. Étage 2 — classifieur de direction (seulement si étage 1 validé)
# ----------------------------------------------------------------------
def fit_direction_classifier(
    data: pd.DataFrame,
    direction_labels: pd.Series,
    hazard_fit: HazardFitResult,
) -> dict:
    """
    N'est appelé que si hazard_fit.economically_exploitable == True.
    Classifieur léger + calibration isotonic, walk-forward split (pas de shuffle).
    """
    from sklearn.ensemble import GradientBoostingClassifier
    from sklearn.calibration import CalibratedClassifierCV
    from sklearn.metrics import roc_auc_score, brier_score_loss

    if not hazard_fit.economically_exploitable:
        raise RuntimeError(
            "Étage 2 non lancé: l'étage 1 n'a pas validé d'effet significatif "
            "ET économiquement exploitable. Voir HazardFitResult."
        )

    split = int(len(data) * 0.7)
    train_idx = slice(0, split)
    test_idx = slice(split, None)

    feature_cols = [c for c in ("n", "rsi14", "rsi7", "atr_ratio") if c in data.columns]
    X = data[feature_cols].to_numpy()
    y = direction_labels.to_numpy()

    base_clf = GradientBoostingClassifier(n_estimators=150, max_depth=3, learning_rate=0.05)
    clf = CalibratedClassifierCV(base_clf, method="isotonic", cv=3)
    clf.fit(X[train_idx], y[train_idx])

    p_test = clf.predict_proba(X[test_idx])[:, 1]
    y_test = y[test_idx]

    auc = roc_auc_score(y_test, p_test) if len(set(y_test)) > 1 else float("nan")
    brier = brier_score_loss(y_test, p_test)

    return {
        "model": clf,
        "feature_cols": feature_cols,
        "test_auc": float(auc),
        "test_brier": float(brier),
        "n_train": int(split),
        "n_test": int(len(data) - split),
    }


# ----------------------------------------------------------------------
# 5. Persistance + interface "is_model_validated" pour l'EA / ai_server.py
# ----------------------------------------------------------------------
def save_hazard_result(result: HazardFitResult, symbol: str, models_dir: Path) -> Path:
    models_dir.mkdir(parents=True, exist_ok=True)
    out_path = models_dir / f"{symbol}_spike_hazard.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result.to_dict(), f, ensure_ascii=False, indent=2)
    logger.info(f"[SPIKE-HAZARD] résultat sauvegardé: {out_path}")
    return out_path


def load_hazard_result(symbol: str, models_dir: Path) -> Optional[dict]:
    path = models_dir / f"{symbol}_spike_hazard.json"
    if not path.exists():
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:
        logger.warning(f"[SPIKE-HAZARD] lecture échouée pour {symbol}: {exc}")
        return None


def is_model_validated(symbol: str, models_dir: Path) -> bool:
    """
    Porte de sécurité: tant que ce n'est pas True, ai_server.py ne doit
    renvoyer AUCUN champ de prédiction hazard à l'EA (pas de faux signal).
    """
    res = load_hazard_result(symbol, models_dir)
    return bool(res and res.get("economically_exploitable"))


def predict_current_hazard(
    symbol: str,
    n_ticks_since_last_spike: int,
    models_dir: Path,
) -> Optional[Tuple[float, str]]:
    """
    Retourne (hazard_pct, regime_label) pour l'état courant, uniquement
    si le modèle est validé pour ce symbole. None sinon (=> l'EA ignore le champ).

    regime_label:
      "ELEVATED_RISK" -> hazard actuel significativement AU-DESSUS de la
                          référence (régime "clustering", confirmé sur
                          Boom500 M1 réel: un spike récent augmente la
                          probabilité d'un nouveau spike proche)
      "COOLDOWN_ACTIVE" -> hazard actuel significativement EN-DESSOUS de la
                          référence (régime "cooldown" classique, si un jour
                          détecté sur un autre symbole/dataset)
      "NORMAL"          -> hazard dans la plage habituelle
    """
    res = load_hazard_result(symbol, models_dir)
    if not res or not res.get("economically_exploitable"):
        return None

    n_grid = np.array(res["n_grid"])
    curve = np.array(res["hazard_curve"])
    n_clamped = min(max(n_ticks_since_last_spike, n_grid.min()), n_grid.max())
    hazard = float(np.interp(n_clamped, n_grid, curve))

    baseline = res["hazard_baseline"]
    direction = res.get("direction", "none")

    if direction == "clustering" and hazard > baseline * (1 + ECONOMIC_EFFECT_THRESHOLD):
        regime = "ELEVATED_RISK"
    elif direction == "cooldown" and hazard < baseline * (1 - ECONOMIC_EFFECT_THRESHOLD):
        regime = "COOLDOWN_ACTIVE"
    else:
        regime = "NORMAL"

    return round(hazard * 100, 3), regime
